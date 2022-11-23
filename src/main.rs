use opencv::core::{Scalar, VecN};
use opencv::types::VectorOfMat;
use opencv::videoio::VideoCapture;
use opencv::{core, highgui, imgproc, prelude::*, videoio, Result};
use std::{thread, time::Duration};

fn get_frame(vid_stream: &mut VideoCapture) -> Option<Mat> {
  let mut frame = Mat::default();
  vid_stream.read(&mut frame).unwrap();
  if frame.size().unwrap().width == 0 {
    None
  } else {
    let mut reduced = Mat::default();
    imgproc::resize(
      &frame,
      &mut reduced,
      core::Size {
        width: 600,
        height: 0,
      },
      0.25f64,
      0.25f64,
      imgproc::INTER_LINEAR,
    )
    .unwrap();
    Some(reduced)
  }
}

struct Tracker {
  midx: i32,
  midy: i32,
  xoffset: i32,
  yoffset: i32,
  color_lower: Scalar,
  color_upper: Scalar,
}

impl Tracker {
  fn new(height: i32, width: i32, color_lower: Scalar, color_upper: Scalar) -> Self {
    Self {
      midx: width / 2,
      midy: height / 2,
      xoffset: 0,
      yoffset: 0,
      color_lower,
      color_upper,
    }
  }

  fn track(&mut self, frame: &mut Mat) -> (i32, i32) {
    let mut blurred = Mat::default();
    let mut hsv = Mat::default();
    let mut mask = Mat::default();
    let mut eroded = Mat::default();
    let mut dilated = Mat::default();
    let mut cnts = VectorOfMat::new();
    imgproc::gaussian_blur(
      frame,
      &mut blurred,
      core::Size {
        width: 11,
        height: 11,
      },
      0.0f64,
      0.0f64,
      imgproc::INTER_LINEAR,
    )
    .unwrap();

    imgproc::cvt_color(&blurred, &mut hsv, imgproc::COLOR_BGR2GRAY, 0).unwrap();
    core::in_range(&hsv, &self.color_lower, &self.color_upper, &mut mask).unwrap();
    imgproc::erode(
      &mask,
      &mut eroded,
      &mask,
      core::Point::new(-1, -1),
      2,
      core::BORDER_CONSTANT,
      imgproc::morphology_default_border_value().unwrap(),
    )
    .unwrap();

    imgproc::dilate(
      &eroded,
      &mut dilated,
      &eroded,
      core::Point::new(-1, -1),
      2,
      core::BORDER_CONSTANT,
      imgproc::morphology_default_border_value().unwrap(),
    )
    .unwrap();

    imgproc::find_contours(
      &dilated,
      &mut cnts,
      imgproc::RETR_EXTERNAL,
      imgproc::CHAIN_APPROX_SIMPLE,
      core::Point::default(),
    )
    .unwrap();

    if !cnts.is_empty() {
      let c = &cnts
        .iter()
        .max_by(|a, b| {
          let _a = imgproc::contour_area(a, false).unwrap();
          let _b = imgproc::contour_area(b, false).unwrap_or(0.0);
          _a.partial_cmp(&_b).unwrap()
        })
        .unwrap();

      let mut center = core::Point2f::default();
      let mut radius = 0.0f32;

      imgproc::min_enclosing_circle(&c, &mut center, &mut radius).unwrap();

      // M = cv2.moments(c)
      // center = (int(M["m10"] / M["m00"]), int(M["m01"] / M["m00"]))

      if radius > 10.0 {
        imgproc::circle(
          frame,
          core::Point::new(center.x as i32, center.y as i32),
          radius as i32,
          Scalar::new(0f64, 255f64, 255f64, 0f64),
          2,
          8,
          0,
        )
        .unwrap();

        imgproc::circle(
          frame,
          core::Point::new(center.x as i32, center.y as i32),
          5,
          Scalar::new(0f64, 0f64, 255f64, 0f64),
          -1,
          8,
          0,
        )
        .unwrap();
        self.xoffset = (center.x as i32) - self.midx;
        self.yoffset = self.midy - (center.y as i32);
      } else {
        self.xoffset = 0;
        self.yoffset = 0;
      }
    } else {
      self.xoffset = 0;
      self.yoffset = 0;
    }

    (self.xoffset, self.yoffset)
  }
}

fn main() -> Result<()> {
  let window = "video capture";
  let green_lower = Scalar::new(50.0f64, 50.0f64, 50.0f64, 0.0f64);
  let green_upper = Scalar::new(70.0f64, 255.0f64, 255.0f64, 0.0f64);
  highgui::named_window(window, 1)?;
  let mut cam = videoio::VideoCapture::from_file("ball_tracking_example.mp4", videoio::CAP_ANY)?;
  thread::sleep(Duration::from_millis(200));
  let mut frame = Mat::default();
  cam.read(&mut frame)?;
  let mut reduced = get_frame(&mut cam).unwrap();
  let core::Size { width, height } = reduced.size().unwrap();
  let mut greentracker = Tracker::new(height, width, green_lower, green_upper);

  let mut more_frames = true;

  while more_frames {
    greentracker.track(&mut reduced);

    highgui::imshow(window, &reduced)?;
    if highgui::wait_key(1)? == 1 & 0xff {
      break;
    }

    if get_frame(&mut cam).is_none() {
      more_frames = false;
    } else {
      reduced = get_frame(&mut cam).unwrap();
    }
  }

  cam.release().unwrap();
  highgui::destroy_all_windows()
}
