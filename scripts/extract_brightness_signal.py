import numpy as np
import cv2

file_path = r"c64_transmission_reinterlaced_cropped.mp4"

video = cv2.VideoCapture(file_path)

current_field = 0
signal = []
while True:
    video.set(cv2.CAP_PROP_POS_FRAMES, current_field)

    ret, frame = video.read()
    if ret:
        print("extracted field ", current_field, " of shape ", frame.shape)
        # calculate luminance
        y = 0.2126*frame[:,:,0] + 0.7152*frame[:,:,1] + 0.0722*frame[:,:,2]
        y99 = np.percentile(y, 99)
        print("y99 = ", y99)
        signal.append(y99)
        current_field = current_field + 1
        #if current_field == 1000:
        #    break
    else:
        break

with open("signal.dat", "w") as file:
    for value in signal:
        file.write(str(value) + "\n")

video.release()
cv2.destroyAllWindows()
