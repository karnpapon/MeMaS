#include <Arduino.h>
#include <WiFi.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <Arduino_JSON.h>
#include <OSCMessage.h>

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
unsigned long gyroDelay = 20;
unsigned long accelerometerDelay = 200;
// unsigned long lastTimeTemperature = 0;
// unsigned long temperatureDelay = 1000;

// slide switch at GPIO5 (D5)
const int switchPin = 5;
int switchState;

// Create a sensor object
Adafruit_MPU6050 mpu;

sensors_event_t a, g, temp;

float gyroX, gyroY, gyroZ;
float accX, accY, accZ;
float temperature;

//Gyroscope sensor deviation
float gyroXerror = 0.07;
float gyroYerror = 0.03;
float gyroZerror = 0.01;

struct gyro{
  float gyroX, gyroY, gyroZ;
};

// Init MPU6050
void initMPU(){
  if (!mpu.begin()) {
    Serial.println("Failed to find MPU6050 chip");
    while (1) {
      delay(10);
    }
  }
  Serial.println("MPU6050 Found!");
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

gyro getGyroReadings(){
  mpu.getEvent(&a, &g, &temp);

  float gyroX_temp = g.gyro.x;
  if(abs(gyroX_temp) > gyroXerror)  {
    gyroX += gyroX_temp/50.00;
  }
  
  float gyroY_temp = g.gyro.y;
  if(abs(gyroY_temp) > gyroYerror) {
    gyroY += gyroY_temp/70.00;
  }

  float gyroZ_temp = g.gyro.z;
  if(abs(gyroZ_temp) > gyroZerror) {
    gyroZ += gyroZ_temp/90.00;
  }

  // readings["gyroX"] = String(gyroX);
  // readings["gyroY"] = String(gyroY);
  // readings["gyroZ"] = String(gyroZ);

  // String jsonString = JSON.stringify(readings);
  // return jsonString;
  return { gyroX,gyroY,gyroZ };
}

String getAccReadings() {
  mpu.getEvent(&a, &g, &temp);
  // Get current acceleration values
  accX = a.acceleration.x;
  accY = a.acceleration.y;
  accZ = a.acceleration.z;
  readings["accX"] = String(accX);
  readings["accY"] = String(accY);
  readings["accZ"] = String(accZ);
  String accString = JSON.stringify (readings);
  return accString;
}

// String getTemperature(){
//   mpu.getEvent(&a, &g, &temp);
//   temperature = temp.temperature;
//   return String(temperature);
// }

void setup() {
  Serial.begin(115200);
  pinMode(switchPin,INPUT);
  initWiFi();
  initMPU();
}

void loop() {
  // turn Gyroscope on/off
  switchState = digitalRead(switchPin);

  if(switchState == HIGH) {
    if ((millis() - lastTime) > gyroDelay) {
      gyro gyro_reading = getGyroReadings();
      OSCMessage msg("/test_plotter_trigger");
      Udp.beginPacket(outIp, outPort);
      msg.add(gyro_reading.gyroX);
      msg.add(gyro_reading.gyroY);
      msg.add(gyro_reading.gyroZ);
      msg.send(Udp);
      Udp.endPacket();
      msg.empty();

      lastTime = millis();
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
