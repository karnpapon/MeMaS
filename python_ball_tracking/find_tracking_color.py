from collections import deque
import numpy as np
import time
import argparse
import imutils
import cv2

ap = argparse.ArgumentParser()
ap.add_argument("-m", "--image", help="path to the (optional) image file")
ap.add_argument("-b", "--buffer", type=int, default=64, help="max buffer size")
args = vars(ap.parse_args())

pts = deque(maxlen=args["buffer"])

img = cv2.imread(args["image"], cv2.IMREAD_COLOR)
fps = 25

def nothing(x):
  pass

cv2.namedWindow("Tracking")
cv2.resizeWindow("Tracking", 450, 200)
cv2.moveWindow("Tracking", 200, 400)
cv2.createTrackbar("LH", "Tracking", 78, 255, nothing)
cv2.createTrackbar("LS", "Tracking", 0, 255, nothing)
cv2.createTrackbar("LV", "Tracking", 190, 255, nothing)
cv2.createTrackbar("UH", "Tracking", 117, 255, nothing)
cv2.createTrackbar("US", "Tracking", 141, 255, nothing)
cv2.createTrackbar("UV", "Tracking", 236, 255, nothing)

while True:
  now = time.time()

  frame = imutils.resize(img, width=600)
  blurred = cv2.GaussianBlur(frame, (11, 11), 0)
  hsv = cv2.cvtColor(blurred, cv2.COLOR_BGR2HSV)

  l_h = cv2.getTrackbarPos("LH", "Tracking")
  l_s = cv2.getTrackbarPos("LS", "Tracking")
  l_v = cv2.getTrackbarPos("LV", "Tracking")

  u_h = cv2.getTrackbarPos("UH", "Tracking")
  u_s = cv2.getTrackbarPos("US", "Tracking")
  u_v = cv2.getTrackbarPos("UV", "Tracking")

  l_b = np.array([l_h, l_s, l_v])
  u_b = np.array([u_h, u_s, u_v])

  mask = cv2.inRange(hsv, l_b, u_b) 
  mask = cv2.erode(mask, None, iterations=2)
  mask = cv2.dilate(mask, None, iterations=2)
  res = cv2.bitwise_and(frame, frame, mask=mask)

  cnts = cv2.findContours(mask.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[-2]
  center = None

  if len(cnts) > 0:
    c = max(cnts, key=cv2.contourArea)
    ((x, y), radius) = cv2.minEnclosingCircle(c)
    M = cv2.moments(c)
    # finding centriod formular: https://learnopencv.com/find-center-of-blob-centroid-using-opencv-cpp-python/
    center = (int(M["m10"] / M["m00"]), int(M["m01"] / M["m00"]))

    if radius > 10:
      cv2.circle(frame, (int(x), int(y)), int(radius), (0, 255, 255), 2)
      cv2.circle(frame, center, 5, (0, 0, 255), -1)

  pts.appendleft(center)

  for i in range(1, len(pts)):
    if pts[i - 1] is None or pts[i] is None:
      continue

    thickness = int(np.sqrt(args["buffer"] / float(i + 1)) * 2.5)
    cv2.line(frame, pts[i - 1], pts[i], (0, 0, 255), thickness)

  cv2.imshow("Frame", frame)
  cv2.imshow("mask", mask)
  cv2.imshow("res", res)

  if cv2.waitKey(1) & 0xFF == 27: break
  elif cv2.getWindowProperty("Frame", 0) == -1: break

  timeDiff = time.time() - now
  if (timeDiff < 1.0/(fps)):
    time.sleep(1.0/(fps) - timeDiff)

cv2.destroyAllWindows()
