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

#define ADC_PIN 21
#define BUTTON_PIN 19
#define SWITCH_PIN 5

// Serial output refresh time
const long SERIAL_REFRESH_TIME = 30;
long refresh_time;

int prev_button_state = LOW;  // The previous state from the input pin
int button_state;  

WiFiUDP Udp;

const char* ssid = "Liu_2.4G";
const char* password = "7811778117";

const IPAddress outIp(192,168,1,111);
unsigned int outPort = 57120; // default SC port

// Create AsyncWebServer object on port 80
// AsyncWebServer server(80);

// Json Variable to Hold Sensor Readings
// JSONVar readings;

// Timer variables
unsigned long lastTime = 0;  
unsigned long lastTimeAcc = 0;
unsigned long gyroDelay = 60;
// unsigned long accelerometerDelay = 200;
// unsigned long lastTimeTemperature = 0;
// unsigned long temperatureDelay = 1000;

int switchState;

// Create a sensor object
// Adafruit_MPU6050 mpu;
MPU6050 mpu(Wire);
// MPU6050 mpu;

sensors_event_t a, g, temp;

float gyroX, gyroY, gyroZ;
// float accX, accY, accZ;
// float temperature;

//Gyroscope sensor deviation
// float gyroXerror = 0.07;
// float gyroYerror = 0.03;
// float gyroZerror = 0.01;

int remappedAngleY = 0;
int remappedAngleX = 0;
int remappedAngleZ = 0;
int limit_gyro_x = 90;
int limit_gyro_y = -70;
int limit_gyro_z = -70;

// struct gyro{
//   float gyroX, gyroY, gyroZ;
// };

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
  pinMode(SWITCH_PIN,INPUT);
  pinMode(BUTTON_PIN,INPUT_PULLUP);
  initWiFi();
  Wire.begin();
  initMPU();
}

void loop() {
  // turn Gyroscope on/off
  switchState = digitalRead(SWITCH_PIN);
  button_state = digitalRead(BUTTON_PIN);
  mpu.update();

  if(prev_button_state == HIGH && button_state == LOW) {
    Serial.println("The button is pressed");
  } else if(prev_button_state == LOW && button_state == HIGH) {
    Serial.println("The button is released");
    OSCMessage msg("/button_reset");
    Udp.beginPacket(outIp, outPort);
    msg.add(button_state);
    msg.send(Udp);
    Udp.endPacket();
    msg.empty();
  }
    
  prev_button_state = button_state;

  if(switchState == HIGH) {
    if (millis() > refresh_time) {
      // clamp
      if (mpu.getAngleX() >= 0 && mpu.getAngleX() <= limit_gyro_x ){        
        remappedAngleX = map((abs(limit_gyro_x-mpu.getAngleX())), 0, limit_gyro_x, 0, 127);
      } else{
        remappedAngleX = 0;
      }

      if (mpu.getAngleY() <= 0 && mpu.getAngleY() >= limit_gyro_y ){
        remappedAngleY = map((abs(limit_gyro_y-mpu.getAngleY())), 0, limit_gyro_y, 0, 127);
      } else{
        remappedAngleY = 0;
      }

      if (mpu.getAngleZ() <= 0 && mpu.getAngleZ() >= limit_gyro_z ){
        remappedAngleZ = map((abs(limit_gyro_z-mpu.getAngleZ())), 0, limit_gyro_z, 0, 127);
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
