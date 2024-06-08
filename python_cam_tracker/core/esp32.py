import cv2
import requests

'''
INFO SECTION
- if you want to monitor raw parameters of ESP32CAM, open the browser and go to http://192.168.x.x/status
- command can be sent through an HTTP get composed in the following way http://192.168.x.x/control?var=VARIABLE_NAME&val=VALUE (check varname and value in status)
'''

# ESP32 URL
URL = "http://192.168.4.1"
AWB = True

# Face recognition and opencv setup
cap = cv2.VideoCapture(URL + ":81/stream")
# insert the full path to haarcascade file if you encounter any problem
# face_classifier = cv2.CascadeClassifier('haarcascade_frontalface_alt.xml')

def set_resolution(url: str, index: int = 1, verbose: bool = False):
  try:
    if verbose:
      resolutions = "10: UXGA(1600x1200)\n9: SXGA(1280x1024)\n8: XGA(1024x768)\n7: SVGA(800x600)\n6: VGA(640x480)\n5: CIF(400x296)\n4: QVGA(320x240)\n3: HQVGA(240x176)\n0: QQVGA(160x120)"
      print("available resolutions\n{}".format(resolutions))

    if index in [10, 9, 8, 7, 6, 5, 4, 3, 0]:
      requests.get(url + "/control?var=framesize&val={}".format(index))
    else:
      print("Wrong index")
  except:
    print("SET_RESOLUTION: something went wrong")

def set_quality(url: str, value: int = 1, verbose: bool = False):
  try:
    if value >= 10 and value <= 63:
      requests.get(url + "/control?var=quality&val={}".format(value))
  except:
    print("SET_QUALITY: something went wrong")

def set_awb(url: str, awb: int = 1):
  try:
    awb = not awb
    requests.get(url + "/control?var=awb&val={}".format(1 if awb else 0))
  except:
    print("SET_QUALITY: something went wrong")
  return awb