from numpy import float32
from cv2 import VideoCapture, getPerspectiveTransform, warpPerspective, line, circle, rectangle, perspectiveTransform
from .trace_header import videoFile, checkPath

video = VideoCapture(videoFile)
checkPath(videoFile)
frameWidth = int(video.get(3))
frameHeight = int(video.get(4))

widthP = int(967)
heightP = int(1585)

# actual table size (as cm)
width = int(152.5 * 5)
height = int(274 * 5)

ratio = (1097/2377)
tableHight = int(height * 0.6)
tableWidth = int(tableHight * ratio)
yOffset = int((height - tableHight) / 2)
xOffset = int((width - tableWidth) / 2)

courtTL = [xOffset, yOffset]
courtTR = [tableWidth+xOffset, yOffset]
courtBL = [xOffset, tableHight+yOffset]
courtBR = [tableWidth+xOffset, tableHight+yOffset]

def tableMap(frame, top_left, top_right, bottom_left, bottom_right):
  pts1 = float32([[top_left, top_right, bottom_left, bottom_right]])
  pts2 = float32([courtTL, courtTR, courtBL, courtBR])
  M = getPerspectiveTransform(pts1, pts2)
  dst = warpPerspective(frame, M, (width, height))
  return dst, M

def showLines(frame):
  rectangle(frame, (0, 0), (width, height), (255, 255, 255), 6)
  rectangle(frame, (xOffset, yOffset), (tableWidth+xOffset,
            tableHight+yOffset), (255, 255, 255), 2)
  rectangle(frame, (xOffset, yOffset+int(tableHight*0.5)),
            (tableWidth+xOffset, yOffset+int(tableHight*0.5)), (255, 255, 255), 2)
  rectangle(frame, (xOffset+int(tableWidth*0.5), yOffset+int(tableHight)), (tableWidth +
            xOffset-int(tableWidth*0.5), tableHight+yOffset-int(tableHight)), (255, 255, 255), 2)
  return frame

def showPoint(frame, M, point):
  points = float32([[point]])
  transformed = perspectiveTransform(points, M)[0][0]
  circle(frame, (int(transformed[0]), int(
      transformed[1])), radius=0, color=(0, 0, 255), thickness=25)
  return frame

def givePoint(M, point):
  points = float32([[point]])
  transformed = perspectiveTransform(points, M)[0][0]
  return (int(transformed[0]), int(transformed[1]))
