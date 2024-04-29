import cv2
import imutils
import numpy as np
from collections import deque
from typing import Any
from pythonosc.udp_client import SimpleUDPClient

top_left = [140,90]
top_right = [452,90]
bottom_left = [452, 260]
bottom_right = [140, 260]
point_matrix1 = np.int32([[top_left,top_right, bottom_left, bottom_right]])


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

class BallTracker:
  """
  Ball Detector model responsible for receiving the frames and detecting the ball
  """

  def __init__(self, pts: deque, color_lower, color_upper, args: dict[str, Any], client: SimpleUDPClient):
    self.pts = pts
    self.color_lower = color_lower
    self.color_upper = color_upper
    self.args = args
    self.client = client

  def mask_area(frame: cv2.typing.MatLike):
    """
    mask specific area, eg. detect ball moving only within table area (top-view, static camera)
    """
    frame = imutils.resize(frame, width=600)
    mask = np.zeros(frame.shape[:2], np.uint8)
    cv2.fillPoly(mask, point_matrix1, (255, 255, 255))
    frame = cv2.bitwise_and(frame, frame, mask=mask) 

  def with_trackbar_adjustment():
    """
    trackbar for finding the target color range (HSV color space)
    """
    
    l_h = cv2.getTrackbarPos("LH", "Tracking")
    l_s = cv2.getTrackbarPos("LS", "Tracking")
    l_v = cv2.getTrackbarPos("LV", "Tracking")

    u_h = cv2.getTrackbarPos("UH", "Tracking")
    u_s = cv2.getTrackbarPos("US", "Tracking")
    u_v = cv2.getTrackbarPos("UV", "Tracking")

    l_b = np.array([l_h, l_s, l_v])
    u_b = np.array([u_h, u_s, u_v])

    return l_b, u_b

  def detect_ball(self, frame: cv2.typing.MatLike):
    # self.mask_area(frame)
    blurred = cv2.GaussianBlur(frame, (11, 11), 0)
    hsv = cv2.cvtColor(blurred, cv2.COLOR_BGR2HSV)

    # l_b, u_b = with_trackbar_adjustment()
    # mask = cv2.inRange(hsv, l_b, u_b)
    mask = cv2.inRange(hsv, self.color_lower, self.color_upper)
    mask = cv2.erode(mask, None, iterations=2)
    mask = cv2.dilate(mask, None, iterations=2)
    # res = cv2.bitwise_and(frame, frame, mask=mask)

    contours, hierarchy = cv2.findContours( mask.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

   # only proceed if at least one contour was found
    if len(contours) > 0:
      # find the largest contour in the mask, then use it to compute the minimum enclosing circle and centroid
      c = max(contours, key=cv2.contourArea)
      ((x, y), radius) = cv2.minEnclosingCircle(c)
      M = cv2.moments(c)
      # finding centriod formular: https://learnopencv.com/find-center-of-blob-centroid-using-opencv-cpp-python/
      center = (int(M["m10"] / M["m00"]), int(M["m01"] / M["m00"]))

      if radius > 5:
        self.pts.appendleft(center)
        cv2.circle(frame, (int(x), int(y)), int(radius), (0, 255, 255), 2)
        cv2.circle(frame, center, 4, (0, 0, 255), -1)
        cv2.putText(frame,"TARGET",(int(x)-10, int(y)-20),cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0,0,255),1)
        self.client.send_message("/test_plotter/1", (center[0] / 320, center[1] / 240))

    for i in range(1, len(self.pts)):
      if self.pts[i - 1] is None or self.pts[i] is None:
        continue

      thickness = int(np.sqrt(self.args["buffer"] / float(i + 1)) * 2)
      cv2.line(frame, self.pts[i - 1], self.pts[i], (0, 0, 255), thickness)

    cv2.imshow("frame", frame)
    # cv2.imshow("warp_frame", frame)
    # cv2.imshow("mask", mask)
    # cv2.imshow("res", res)
