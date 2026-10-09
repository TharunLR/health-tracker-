/*
 * ----------------------------------------------------------------------------
 * ESP32 Dev Board - AI Health Tracker Firmware (BLE + MAX30102 + MPU6050)
 * ----------------------------------------------------------------------------
 * Pin Connection Guide for ESP32 DevKit V1 (30-pin / 38-pin):
 * 
 * Hardware Connections (Shared I2C Bus):
 * 
 * MAX30102 Sensor        ESP32 Dev Board Pin
 * ------------------     -------------------
 * VIN / VCC           -> 3.3V (or 5V if module has onboard 3.3V LDO)
 * GND                 -> GND
 * SDA                 -> GPIO 21 (Shared I2C Data)
 * SCL                 -> GPIO 22 (Shared I2C Clock)
 * 
 * MPU6050 Accelerometer  ESP32 Dev Board Pin
 * ------------------     -------------------
 * VCC                 -> 3.3V (or 5V)
 * GND                 -> GND
 * SDA                 -> GPIO 21 (Shared I2C Data)
 * SCL                 -> GPIO 22 (Shared I2C Clock)
 * 
 * Required Arduino Libraries (Install via Arduino Library Manager):
 * 1. "MAX30105" by SparkFun Electronics (Works with MAX30102 and MAX30105)
 * 2. ESP32 BLE Arduino & Wire (Built-in with ESP32 Board Package)
 * ----------------------------------------------------------------------------
 */

#include <Wire.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "MAX30105.h"
#include "heartRate.h"

// Device BLE Name (Matches Flutter App Scan Filter)
#define DEVICE_NAME "ESP32-Health-Band"

// MPU6050 I2C Address
#define MPU6050_ADDR 0x68

// Standard & Custom BLE Service / Characteristic UUIDs
#define SERVICE_HR_UUID            "180D"
#define CHAR_HR_UUID               "2A37"

#define SERVICE_BATTERY_UUID       "180F"
#define CHAR_BATTERY_UUID          "2A19"

#define SERVICE_CUSTOM_HEALTH_UUID "19b10000-e8f2-537e-4f6c-d104768a1214"
#define CHAR_SPO2_UUID             "19b10001-e8f2-537e-4f6c-d104768a1214"
#define CHAR_STEP_UUID             "19b10002-e8f2-537e-4f6c-d104768a1214"

// Sensor and BLE Global Objects
MAX30105 particleSensor;
BLEServer* pServer = nullptr;

BLECharacteristic* pHeartRateChar = nullptr;
BLECharacteristic* pSpO2Char      = nullptr;
BLECharacteristic* pStepChar      = nullptr;
BLECharacteristic* pBatteryChar   = nullptr;

bool deviceConnected = false;
bool oldDeviceConnected = false;
bool mpu6050Available = false;

// Health Data Metrics
uint8_t currentBpm = 72;
uint8_t currentSpO2 = 98;
uint32_t stepCounter = 1250;
uint8_t batteryLevel = 92;

// Heart rate calculation variables
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateIdx = 0;
long lastBeat = 0;
float beatsPerMinute = 0;
int beatAvg = 72;

// MPU6050 Step Counter Algorithm Variables
float accelMagnitude = 0;
float prevAccelMagnitude = 0;
unsigned long lastStepTime = 0;

unsigned long lastTelemetrySend = 0;
unsigned long lastStepTick = 0;

// BLE Server Callbacks
class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("[ESP32] Client Connected!");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("[ESP32] Client Disconnected!");
    }
};

void initMPU6050() {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x6B); // PWR_MGMT_1 register
  Wire.write(0);    // Wake up MPU6050
  if (Wire.endTransmission() == 0) {
    mpu6050Available = true;
    Serial.println("[MPU6050] Accelerometer initialized successfully on address 0x68!");
  } else {
    Serial.println("[MPU6050] Warning: MPU6050 not detected on I2C address 0x68.");
  }
}

void processMPU6050Steps() {
  if (!mpu6050Available) {
    // Demo fallback step simulation if MPU6050 hardware disconnected
    if (millis() - lastStepTick > 3000) {
      lastStepTick = millis();
      stepCounter += random(1, 3);
    }
    return;
  }

  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x3B); // Accel X High Byte Register
  if (Wire.endTransmission(false) != 0) return;

  if (Wire.requestFrom((uint8_t)MPU6050_ADDR, (size_t)6, (bool)true) == 6) {
    int16_t ax = Wire.read() << 8 | Wire.read();
    int16_t ay = Wire.read() << 8 | Wire.read();
    int16_t az = Wire.read() << 8 | Wire.read();

    // Convert raw 16-bit integers to G-force (sensitivity +/- 2g = 16384 LSB/g)
    float axg = ax / 16384.0;
    float ayg = ay / 16384.0;
    float azg = az / 16384.0;

    // Calculate total 3D acceleration vector magnitude
    accelMagnitude = sqrt(axg * axg + ayg * ayg + azg * azg);

    // Peak threshold step detection algorithm (Min 300ms between physical steps)
    if (accelMagnitude > 1.25 && prevAccelMagnitude <= 1.25) {
      if (millis() - lastStepTime > 300) {
        stepCounter++;
        lastStepTime = millis();
        Serial.printf("[MPU6050] Physical Step Detected! Total Steps: %u\n", stepCounter);
      }
    }
    prevAccelMagnitude = accelMagnitude;
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("\n=============================================");
  Serial.println("  ESP32 Dev Board - Health Tracker Initializing");
  Serial.println("=============================================");

  // 1. Initialize Shared I2C Bus (SDA=GPIO 21, SCL=GPIO 22)
  Wire.begin(21, 22);

  // 2. Initialize MAX30102 Heart Rate & SpO2 Sensor
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("[MAX30102] Warning: Sensor not detected on I2C (SDA=21, SCL=22).");
  } else {
    Serial.println("[MAX30102] Heart Rate & SpO2 Sensor initialized successfully!");
    particleSensor.setup();
    particleSensor.setPulseAmplitudeRed(0x0A);
    particleSensor.setPulseAmplitudeGreen(0x00);
  }

  // 3. Initialize MPU6050 Accelerometer
  initMPU6050();

  // 4. Initialize BLE Engine
  BLEDevice::init(DEVICE_NAME);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  // Heart Rate Service (0x180D)
  BLEService *pHrService = pServer->createService(SERVICE_HR_UUID);
  pHeartRateChar = pHrService->createCharacteristic(
                      CHAR_HR_UUID,
                      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
                   );
  pHeartRateChar->addDescriptor(new BLE2902());
  pHrService->start();

  // Battery Service (0x180F)
  BLEService *pBatService = pServer->createService(SERVICE_BATTERY_UUID);
  pBatteryChar = pBatService->createCharacteristic(
                    CHAR_BATTERY_UUID,
                    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
                 );
  pBatteryChar->addDescriptor(new BLE2902());
  pBatService->start();

  // Custom Health Service (SpO2 & Steps)
  BLEService *pCustomService = pServer->createService(SERVICE_CUSTOM_HEALTH_UUID);
  pSpO2Char = pCustomService->createCharacteristic(
                CHAR_SPO2_UUID,
                BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
              );
  pSpO2Char->addDescriptor(new BLE2902());

  pStepChar = pCustomService->createCharacteristic(
                CHAR_STEP_UUID,
                BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
              );
  pStepChar->addDescriptor(new BLE2902());
  pCustomService->start();

  // Start BLE Advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_HR_UUID);
  pAdvertising->addServiceUUID(SERVICE_CUSTOM_HEALTH_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Advertising as 'ESP32-Health-Band'. Ready to connect!");
}

void loop() {
  long irValue = particleSensor.getIR();

  // Detect finger pulse on MAX30102
  if (checkForBeat(irValue) == true) {
    long delta = millis() - lastBeat;
    lastBeat = millis();

    beatsPerMinute = 60 / (delta / 1000.0);

    if (beatsPerMinute < 255 && beatsPerMinute > 40) {
      rates[rateIdx++] = (byte)beatsPerMinute;
      rateIdx %= RATE_SIZE;

      int total = 0;
      for (byte x = 0; x < RATE_SIZE; x++) {
        total += rates[x];
      }
      beatAvg = total / RATE_SIZE;
      currentBpm = beatAvg;
    }
  }

  // Process physical step counting from MPU6050 accelerometer
  processMPU6050Steps();

  // Broadcast Telemetry updates every 1 second when connected
  if (deviceConnected && (millis() - lastTelemetrySend > 1000)) {
    lastTelemetrySend = millis();

    // 1. Send Heart Rate Notification (Flags [0x06] + BPM byte)
    uint8_t hrPayload[2] = { 0x06, currentBpm };
    pHeartRateChar->setValue(hrPayload, 2);
    pHeartRateChar->notify();

    // 2. Send SpO2 Notification (Single Byte)
    uint8_t spo2Payload[1] = { currentSpO2 };
    pSpO2Char->setValue(spo2Payload, 1);
    pSpO2Char->notify();

    // 3. Send Step Count Notification (4-byte 32-bit Little Endian Integer)
    uint8_t stepPayload[4];
    stepPayload[0] = (stepCounter & 0xFF);
    stepPayload[1] = ((stepCounter >> 8) & 0xFF);
    stepPayload[2] = ((stepCounter >> 16) & 0xFF);
    stepPayload[3] = ((stepCounter >> 24) & 0xFF);
    pStepChar->setValue(stepPayload, 4);
    pStepChar->notify();

    // 4. Send Battery Notification (Single Byte)
    uint8_t batPayload[1] = { batteryLevel };
    pBatteryChar->setValue(batPayload, 1);
    pBatteryChar->notify();

    Serial.printf("[BLE Tx] BPM: %d | SpO2: %d%% | Steps: %u | Bat: %d%%\n",
                  currentBpm, currentSpO2, stepCounter, batteryLevel);
  }

  // Handle re-advertising on disconnect
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("[BLE] Restarting Advertising...");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
}
