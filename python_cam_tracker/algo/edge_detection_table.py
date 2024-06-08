import cv2
import numpy as np

image = cv2.imread('resources/pp.png')
# image = cv2.resize(image, (960, 1024))
mask = np.zeros(image.shape, np.uint8)
gray = cv2.cvtColor(image,cv2.COLOR_BGR2GRAY)
blur = cv2.GaussianBlur(gray, (3,3), 0)
canny = cv2.Canny(blur, 150, 255, 1)
kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5,5))

# Find Vertical Lines
# ------ 
vertical_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1,3))
remove_horizontal = cv2.morphologyEx(canny, cv2.MORPH_OPEN, vertical_kernel)

kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5,5))
dilate_vertical = cv2.morphologyEx(remove_horizontal, cv2.MORPH_CLOSE, kernel, iterations=5)

minLineLength = 100
maxLineGap = 10
lines = cv2.HoughLinesP(dilate_vertical,1,np.pi/180,50,minLineLength,maxLineGap)
for line in lines:
    for x1,y1,x2,y2 in line:
        cv2.line(mask,(x1,y1),(x2,y2),(255,255,255),3)
cv2.imwrite('output/vertical_mask.png', mask)
# ------ 

# Find Horizontal Lines
# ------ 
horizontal_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3,1))
remove_vertical = cv2.morphologyEx(canny, cv2.MORPH_OPEN, horizontal_kernel)

kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (9,9))
dilate_horizontal = cv2.morphologyEx(remove_vertical, cv2.MORPH_CLOSE, kernel, iterations=3)

minLineLength = 10
maxLineGap = 300
horizontal_mask = np.zeros(image.shape, np.uint8)
lines = cv2.HoughLinesP(dilate_horizontal,1,np.pi/180,100,minLineLength,maxLineGap)
for line in lines:
    for x1,y1,x2,y2 in line:
        cv2.line(mask,(x1,y1),(x2,y2),(255,255,255),3)
        cv2.line(horizontal_mask,(x1,y1),(x2,y2),(255,255,255),3)
cv2.imwrite('output/horizontal_mask.png', horizontal_mask)
# ------ 

mask = cv2.cvtColor(mask, cv2.COLOR_BGR2GRAY)
cnts = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
cnts = cnts[0] if len(cnts) == 2 else cnts[1]
for c in cnts:
    cv2.drawContours(image, [c], -1, (36,255,12), 2)

cv2.imwrite('output/remove_vertical.png', remove_vertical)
cv2.imwrite('output/remove_horizontal.png', remove_horizontal)
cv2.imwrite('output/dilate_horizontal.png', dilate_horizontal)
cv2.imwrite('output/mask.png', mask)
cv2.imwrite('output/image.png', image)
if cv2.waitKey(1) & 0xFF == 27: 
  exit()