from collections import deque
import numpy as np
import time
import argparse
import cv2
from core.ball_tracker import BallTracker
from pythonosc import udp_client

ap = argparse.ArgumentParser()
ap.add_argument("-v", "--video", help="path to the (optional) video file")
ap.add_argument("-b", "--buffer", type=int, default=16, help="max buffer size")
ap.add_argument("--ip", default="127.0.0.1", help="The ip of the OSC server")
ap.add_argument("--port", type=int, default=57120, help="The port the OSC server is listening on")
args = vars(ap.parse_args())

colorLower = (78, 0, 137)
colorUpper = (117, 141, 236)
pts = deque(maxlen=args["buffer"])

client = udp_client.SimpleUDPClient(args["ip"], args["port"])

if not args.get("video", False):
  camera = cv2.VideoCapture(0)
else:
  camera = cv2.VideoCapture(args["video"])

fps = camera.get(cv2.CAP_PROP_FPS) 

ball_tracker = BallTracker(pts, colorLower, colorUpper, args, client)

while True:
  now = time.time()
  (grabbed, frame) = camera.read()

  if args.get("video") and not grabbed:
    break

  ball_tracker.detect_ball(frame)

  # esc to quit
  if cv2.waitKey(1) & 0xFF == 27: break

  timeDiff = time.time() - now
  if (timeDiff < 1.0/(fps)):
    time.sleep(1.0/(fps) - timeDiff)

camera.release()
cv2.destroyAllWindows()
