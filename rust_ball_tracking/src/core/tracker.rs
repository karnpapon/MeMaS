use opencv::types::VectorOfMat;
use opencv::core::Scalar;
use opencv::{core, prelude::Mat, imgproc };

pub struct Tracker {
  midx: i32,
  midy: i32,
  xoffset: i32,
  yoffset: i32,
  color_lower: Scalar,
  color_upper: Scalar,
}

impl Tracker {
  pub fn new(height: i32, width: i32, color_lower: Scalar, color_upper: Scalar) -> Self {
    Self {
      color_lower,
      color_upper,
      midx: width / 2,
      midy: height / 2,
      xoffset: 0,
      yoffset: 0,
    }
  }

  pub fn track(&mut self, frame: &mut Mat) -> (i32, i32) {
    let mut blurred = Mat::default();
    let mut hsv = Mat::default();
    let mut mask = Mat::default();
    let mut eroded = Mat::default();
    let mut dilated = Mat::default();
    let mut cnts = VectorOfMat::new();

    // resize the frame, blur it, and convert it to the HSV color space
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
      if radius > 5.0 {
       
        // imgproc::rectangle(
        //   frame,
        //   core::Rect::new(ball_center.x - ( radius as i32 ), ball_center.y - ( radius as i32 ), radius as i32 * 2, radius as i32 * 2),
        //   Scalar::new(0f64, 255f64, 255f64, 0f64),
        //   1i32,
        //   imgproc::LINE_8,
        //   0i32
        // )
        // .unwrap();

        // Finds space required by the text so that we can put a background with that amount of width.
        // if let Ok(text_size)  = imgproc::get_text_size("Ping Pong ball", imgproc::FONT_HERSHEY_SIMPLEX, 0.25, 1, &mut 0){
          // imgproc::rectangle(
          //   frame,
          //   core::Rect::new(ball_center.x - ( radius as i32 ) - 15, ball_center.y - ( radius as i32 ) - 15, text_size.width, text_size.height),
          //   Scalar::new(0f64, 255f64, 255f64, 0f64),
          //   1i32,
          //   4,
          //   0i32
          // )
          // .unwrap();
          // img = cv2.rectangle(img, (x1, y1 - 20), (x1 + w, y1), color, -1)
          // img = cv2.putText(img, label, (x1, y1 - 5),
          //                     cv2.FONT_HERSHEY_SIMPLEX, 0.6, text_color, 1)
          
          imgproc::put_text(
            frame, 
            "pingpong", 
            core::Point::new(ball_center.x - ( radius as i32 ) - 10, ball_center.y - ( radius as i32 ) - 10 ), 
            imgproc::FONT_HERSHEY_SIMPLEX, 
            0.5, 
            Scalar::new(0f64, 255f64, 255f64, 0f64), 
            1i32, 
            imgproc::FILLED, 
            false
          ).unwrap();
        // }

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
        self.xoffset = (ball_center.x) - self.midx;
        self.yoffset = self.midy - (ball_center.y);
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