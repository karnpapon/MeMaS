from collections import deque
import numpy as np
import time
import argparse
import cv2
from core.table_mapping import tableMap, showPoint
from core.ball_tracker import BallTracker

ap = argparse.ArgumentParser()
ap.add_argument("-v", "--video", help="path to the (optional) video file")
ap.add_argument("-b", "--buffer", type=int, default=16, help="max buffer size")
args = vars(ap.parse_args())

colorLower = (78, 0, 137)
colorUpper = (117, 141, 236)
# colorLower = (15, 73, 59)
# colorUpper = (63, 255, 255)
pts = deque(maxlen=args["buffer"])

if not args.get("video", False):
  camera = cv2.VideoCapture(0)
else:
  camera = cv2.VideoCapture(args["video"])

fps = camera.get(cv2.CAP_PROP_FPS) 

# def nothing(x):
#   pass

# cv2.namedWindow("Tracking")
# cv2.resizeWindow("Tracking", 450, 200)
# cv2.moveWindow("Tracking", 200, 400)
# cv2.createTrackbar("LH", "Tracking", 78, 255, nothing)
# cv2.createTrackbar("LS", "Tracking", 0, 255, nothing)
# cv2.createTrackbar("LV", "Tracking", 190, 255, nothing)
# cv2.createTrackbar("UH", "Tracking", 117, 255, nothing)
# cv2.createTrackbar("US", "Tracking", 141, 255, nothing)
# cv2.createTrackbar("UV", "Tracking", 236, 255, nothing)

ball_tracker = BallTracker(pts, colorLower, colorUpper, args)

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
