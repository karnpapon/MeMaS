use clap::{Arg, Command};
use opencv::core::Scalar;
use opencv::{core as cv_core, highgui, prelude::*, videoio, Result};
use std::{thread, time::Duration};
use std::time::{SystemTime, UNIX_EPOCH};

mod core;

use core::tracker::Tracker;
use core::processor::get_frame;

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
    Some(_) => {
      cam = {
        // example case.
        let f = "ball_tracking_example.mp4";
        target_color_lower = Scalar::new(50.0f64, 50.0f64, 50.0f64, 0.0f64); // green
        target_color_upper = Scalar::new(70.3f64, 255.0f64, 255.0f64, 0.0f64); // green
        videoio::VideoCapture::from_file(f, videoio::CAP_ANY)?
      }
    }
    None => cam = videoio::VideoCapture::new(0, videoio::CAP_ANY)?,
  }

  // allow the camera or video file to warm up
  thread::sleep(Duration::from_millis(200));

  let mut frame = get_frame(&mut cam).unwrap();
  let cv_core::Size { width, height } = frame.size().unwrap();
  println!("Size:: width={:?}, height:{:?}", width, height);
  let mut greentracker = Tracker::new(height, width, target_color_lower, target_color_upper);

  let mut more_frames = true;

  let fps = 25;

  let start = SystemTime::now();
  let since_the_epoch = start
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards");
  let mut frameref_ms = (since_the_epoch.as_millis()) as i32;
  let frametime_ms = 1000/fps;

  while more_frames {

    frameref_ms += frametime_ms;

    greentracker.track(&mut frame);

    highgui::imshow(window, &frame)?;
    let k = highgui::wait_key(frameref_ms - (SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis()) as i32 ).unwrap() & 0xFF;
    if k == 27 {
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
