use clap::{Arg, Command};
use opencv::core::Scalar;
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
    let reduced_size = reduced.size().unwrap();
    imgproc::resize(
      &frame,
      &mut reduced,
      reduced_size,
      1.0,
      1.0,
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
      color_lower,
      color_upper,
      midx: width / 2,
      midy: height / 2,
      xoffset: 0,
      yoffset: 0,
    }
  }

  fn track(&mut self, frame: &mut Mat) -> (i32, i32) {
    let mut blurred = Mat::default();
    let mut hsv = Mat::default();
    let mut mask = Mat::default();
    let mut eroded = Mat::default();
    let mut dilated = Mat::default();
    let mut cnts = VectorOfMat::new();

    // resize the frame, blur it, and convert it to the HSV
    // color space
    imgproc::gaussian_blur(
      frame,
      &mut blurred,
      core::Size {
        width: 11,
        height: 11,
      },
      0.0f64,
      0.0f64,
      core::BORDER_DEFAULT,
    )
    .unwrap();
    imgproc::cvt_color(&blurred, &mut hsv, imgproc::COLOR_BGR2HSV, 0).unwrap();

    // construct a mask for the color then perform
    // a series of dilations and erosions to remove any small
    // blobs left in the mask
    let point_center = core::Point::new(-1, -1);
    let border_const = core::BORDER_CONSTANT;
    let border_value = imgproc::morphology_default_border_value().unwrap();
    let kernel = imgproc::get_structuring_element(
      imgproc::MORPH_RECT,
      core::Size::from((5, 5)),
      core::Point::from((-1, -1)),
    )
    .unwrap();
    core::in_range(&hsv, &self.color_lower, &self.color_upper, &mut mask).unwrap();
    imgproc::erode(
      &mask,
      &mut eroded,
      &kernel,
      point_center,
      2,
      border_const,
      border_value,
    )
    .unwrap();
    imgproc::dilate(
      &eroded,
      &mut dilated,
      &kernel,
      point_center,
      2,
      border_const,
      border_value,
    )
    .unwrap();

    // find contours in the mask and initialize the current
    // (x, y) center of the ball
    imgproc::find_contours(
      &dilated,
      &mut cnts,
      imgproc::RETR_EXTERNAL,
      imgproc::CHAIN_APPROX_SIMPLE,
      core::Point::default(),
    )
    .unwrap();

    // only proceed if at least one contour was found
    if !cnts.is_empty() {
      // find the largest contour in the mask, then use
      // it to compute the minimum enclosing circle and
      // centroid
      let contour = &cnts
        .iter()
        .max_by(|a, b| {
          let _a = imgproc::contour_area(a, false).unwrap();
          let _b = imgproc::contour_area(b, false).unwrap();
          _a.partial_cmp(&_b).unwrap()
        })
        .unwrap();

      let mut enclosed_pos = core::Point2f::default();
      let mut radius = 0.0f32;

      imgproc::min_enclosing_circle(&contour, &mut enclosed_pos, &mut radius).unwrap();

      let M = imgproc::moments(&contour, false).unwrap();
      let ball_center = core::Point::new((M.m10 / M.m00) as i32, (M.m01 / M.m00) as i32);

      // only proceed if the radius meets a minimum size
      if radius > 10.0 {
        // draw the circle and centroid on the frame,
        // then update the list of tracked points
        imgproc::circle(
          frame,
          core::Point::new(enclosed_pos.x as i32, enclosed_pos.y as i32),
          radius as i32,
          Scalar::new(0f64, 255f64, 255f64, 0f64),
          2,
          8,
          0,
        )
        .unwrap();

        imgproc::circle(
          frame,
          ball_center,
          5,
          Scalar::new(0f64, 0f64, 255f64, 0f64),
          -1,
          8,
          0,
        )
        .unwrap();
        self.xoffset = (ball_center.x as i32) - self.midx;
        self.yoffset = self.midy - (ball_center.y as i32);
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
  let window = "open-cv rust ball tracking";
  let mut cam;

  // [TODO] figure out how to allow arg without value (eg. just `--example`  not `--example "default"`)
  let commands = Command::new("PingPong ball tracking tool.")
    .author("Karnpapon Boonput <karnpapon@gmail.com>")
    .version("0.1.0")
    .about("an easy computer vision tool for ball tracking via opencv.")
    .arg(
      Arg::new("example-file")
        .short('e')
        .long("example")
        .help("run example program by using local file."),
    )
    .get_matches();

  // define the lower and upper boundaries color in the HSV color space.
  // For HSV, hue range is [0,179], saturation range is [0,255], and value range is [0,255].
  // https://docs.opencv.org/4.x/df/d9d/tutorial_py_colorspaces.html
  // find color: https://hslpicker.com/
  let mut target_color_lower = Scalar::new(15.0f64, 50.0f64, 50.0f64, 0.0f64); // orange
  let mut target_color_upper = Scalar::new(35.0f64, 255.0f64, 255.0f64, 0.0f64); // orange

  highgui::named_window(window, 1)?;
  highgui::set_window_property(window, highgui::WND_PROP_TOPMOST, 1.0f64)?;

  match commands.get_one::<String>("example-file") {
    Some(v) => {
      cam = {
        // example case.
        let f = "ball_tracking_example.mp4";
        target_color_lower = Scalar::new(50.0f64, 50.0f64, 50.0f64, 0.0f64); // green
        target_color_upper = Scalar::new(70.3f64, 255.0f64, 255.0f64, 0.0f64); // green
        videoio::VideoCapture::from_file(&f, videoio::CAP_ANY)?
      }
    }
    None => cam = videoio::VideoCapture::new(0, videoio::CAP_ANY)?,
  }

  // allow the camera or video file to warm up
  thread::sleep(Duration::from_millis(200));

  let mut frame = get_frame(&mut cam).unwrap();
  let core::Size { width, height } = frame.size().unwrap();
  println!("Size:: width={:?}, height:{:?}", width, height);
  let mut greentracker = Tracker::new(height, width, target_color_lower, target_color_upper);

  let mut more_frames = true;

  while more_frames {
    greentracker.track(&mut frame);

    highgui::imshow(window, &frame)?;
    if highgui::wait_key(10)? > 0 {
      break;
    }

    match get_frame(&mut cam) {
      Some(f) => frame = f,
      None => more_frames = false,
    }
  }

  cam.release().unwrap();
  highgui::destroy_all_windows()
}
