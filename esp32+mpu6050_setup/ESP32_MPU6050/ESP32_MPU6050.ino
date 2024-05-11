#include "Wire.h"
#include <Arduino.h>
#include <WiFi.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
// #include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Arduino_JSON.h>
#include <OSCMessage.h>
#include <MPU6050_light.h>
// #include <MPU6050.h>
// #include <SimpleKalmanFilter.h>

// SimpleKalmanFilter simpleKalmanFilter(2, 2, 0.01);

// Serial output refresh time
const long SERIAL_REFRESH_TIME = 30;
long refresh_time;

// float accPitch = 0;
// float accRoll = 0;
// float kalPitch = 0;
// float kalRoll = 0;

#define ADC_PIN 21

WiFiUDP Udp;

const char* ssid = "Liu_2.4G";
const char* password = "7811778117";

const IPAddress outIp(192,168,1,111);
unsigned int outPort = 57120; // default SC port

// Create AsyncWebServer object on port 80
// AsyncWebServer server(80);

// Json Variable to Hold Sensor Readings
JSONVar readings;

// Timer variables
unsigned long lastTime = 0;  
unsigned long lastTimeAcc = 0;
unsigned long gyroDelay = 60;
// unsigned long accelerometerDelay = 200;
// unsigned long lastTimeTemperature = 0;
// unsigned long temperatureDelay = 1000;

// slide switch at GPIO5 (D5)
const int switchPin = 5;
int switchState;

// Create a sensor object
// Adafruit_MPU6050 mpu;
MPU6050 mpu(Wire);
// MPU6050 mpu;

sensors_event_t a, g, temp;

float gyroX, gyroY, gyroZ;
float accX, accY, accZ;
float temperature;

//Gyroscope sensor deviation
float gyroXerror = 0.07;
float gyroYerror = 0.03;
float gyroZerror = 0.01;

int remappedAngleY = 0;
int remappedAngleX = 0;
int remappedAngleZ = 0;
int limit_gyro_x = 90;
int limit_gyro_y = 100;
int limit_gyro_z = 90;

struct gyro{
  float gyroX, gyroY, gyroZ;
};

void initMPU(){
  byte status = mpu.begin();
  Serial.print(F("MPU6050 status: "));
  Serial.println(status);
  while(status!=0){ } // stop everything if could not connect to MPU6050
  
  Serial.println(F("Calculating offsets, do not move MPU6050"));
  delay(1000);
  // mpu.upsideDownMounting = true; // uncomment this line if the MPU6050 is mounted upside-down
  mpu.calcOffsets(); // gyro and accelero
  Serial.println("Done!\n");
}

// Init MPU6050
// void initMPU(){

//   if (!mpu.begin()) {
//     Serial.println("Failed to find MPU6050 chip");
//     while (1) {
//       delay(10);
//     }
//   }
//   Serial.println("MPU6050 Found!");

//   mpu.setAccelerometerRange(MPU6050_RANGE_8_G);

//   Serial.print("Accelerometer range set to: ");
//   switch (mpu.getAccelerometerRange()) {
//   case MPU6050_RANGE_2_G:
//     Serial.println("+-2G");
//     break;
//   case MPU6050_RANGE_4_G:
//     Serial.println("+-4G");
//     break;
//   case MPU6050_RANGE_8_G:
//     Serial.println("+-8G");
//     break;
//   case MPU6050_RANGE_16_G:
//     Serial.println("+-16G");
//     break;
//   }
//   mpu.setGyroRange(MPU6050_RANGE_500_DEG);
//   Serial.print("Gyro range set to: ");
//   switch (mpu.getGyroRange()) {
//   case MPU6050_RANGE_250_DEG:
//     Serial.println("+- 250 deg/s");
//     break;
//   case MPU6050_RANGE_500_DEG:
//     Serial.println("+- 500 deg/s");
//     break;
//   case MPU6050_RANGE_1000_DEG:
//     Serial.println("+- 1000 deg/s");
//     break;
//   case MPU6050_RANGE_2000_DEG:
//     Serial.println("+- 2000 deg/s");
//     break;
//   }

//   mpu.setFilterBandwidth(MPU6050_BAND_5_HZ);
//   Serial.print("Filter bandwidth set to: ");
//   switch (mpu.getFilterBandwidth()) {
//   case MPU6050_BAND_260_HZ:
//     Serial.println("260 Hz");
//     break;
//   case MPU6050_BAND_184_HZ:
//     Serial.println("184 Hz");
//     break;
//   case MPU6050_BAND_94_HZ:
//     Serial.println("94 Hz");
//     break;
//   case MPU6050_BAND_44_HZ:
//     Serial.println("44 Hz");
//     break;
//   case MPU6050_BAND_21_HZ:
//     Serial.println("21 Hz");
//     break;
//   case MPU6050_BAND_10_HZ:
//     Serial.println("10 Hz");
//     break;
//   case MPU6050_BAND_5_HZ:
//     Serial.println("5 Hz");
//     break;
//   }
// }

// Initialize WiFi
void initWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  Serial.println("");
  Serial.print("Connecting to WiFi...");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(1000);
  }
  Serial.println("");
  Serial.println(WiFi.localIP());
}

// gyro getGyroReadings(){
  // mpu.getEvent(&a, &g, &temp);

  // float gyroX_temp = g.gyro.x;
  // if(abs(gyroX_temp) > gyroXerror)  {
  //   gyroX += gyroX_temp/50.00;
  // }
  
  // float gyroY_temp = g.gyro.y;
  // if(abs(gyroY_temp) > gyroYerror) {
  //   gyroY += gyroY_temp/70.00;
  // }

  // float gyroZ_temp = g.gyro.z;
  // if(abs(gyroZ_temp) > gyroZerror) {
  //   gyroZ += gyroZ_temp/90.00;
  // }

  // readings["gyroX"] = String(gyroX);
  // readings["gyroY"] = String(gyroY);
  // readings["gyroZ"] = String(gyroZ);

  // String jsonString = JSON.stringify(readings);
  // return jsonString;
  // return { g.gyro.x,g.gyro.y,g.gyro.z };
// }

// String getAccReadings() {
//   mpu.getEvent(&a, &g, &temp);
//   // Get current acceleration values
//   accX = a.acceleration.x;
//   accY = a.acceleration.y;
//   accZ = a.acceleration.z;
//   readings["accX"] = String(accX);
//   readings["accY"] = String(accY);
//   readings["accZ"] = String(accZ);
//   String accString = JSON.stringify (readings);
//   return accString;
// }

// String getTemperature(){
//   mpu.getEvent(&a, &g, &temp);
//   temperature = temp.temperature;
//   return String(temperature);
// }

void setup() {
  Serial.begin(115200);
  pinMode(switchPin,INPUT);
  initWiFi();
  Wire.begin();
  initMPU();
}

void loop() {
  // turn Gyroscope on/off
  switchState = digitalRead(switchPin);

  if(switchState == HIGH) {
    mpu.update();

    if (millis() > refresh_time) {

      // clamp
      if ( mpu.getAngleX() >= 0 && mpu.getAngleX() <= limit_gyro_x ){
        remappedAngleX = map((abs(limit_gyro_x-mpu.getAngleX())), 0, limit_gyro_x, 0, 127);
      } else{
        remappedAngleX = 0;
      }

      if (mpu.getAngleY() >= 0 && mpu.getAngleY() <= limit_gyro_y ){
        remappedAngleY = map((abs(limit_gyro_y-mpu.getAngleY())), 0, limit_gyro_y, 0, 127);
      } else{
        remappedAngleY = 0;
      }

      if (mpu.getAngleZ() >= 0 && mpu.getAngleZ() <= limit_gyro_z ){
        remappedAngleZ = map((abs(mpu.getAngleZ())), 0, limit_gyro_z, 0, 127);
      } else{
        remappedAngleZ = 0;
      }

      OSCMessage msg("/gyro_read");
      Udp.beginPacket(outIp, outPort);
      msg.add(remappedAngleX);
      msg.add(remappedAngleY);
      msg.add(remappedAngleZ);
      msg.send(Udp);
      Udp.endPacket();
      msg.empty();

      // Serial.println();
      refresh_time = millis() + SERIAL_REFRESH_TIME;
    }

    // if ((millis() - lastTimeAcc) > accelerometerDelay) {
    //   // Send Events to the Web Server with the Sensor Readings
    //   // events.send(getAccReadings().c_str(),"accelerometer_readings",millis());
    //   Serial.print("Acceleration: ");
    //   Serial.print(getAccReadings().c_str());
    //   Serial.print('\n');
    //   lastTimeAcc = millis();
    // }
    // if ((millis() - lastTimeTemperature) > temperatureDelay) {
      // Send Events to the Web Server with the Sensor Readings
      // events.send(getTemperature().c_str(),"temperature_reading",millis());
      // lastTimeTemperature = millis();
    // }

   
  } 
}
