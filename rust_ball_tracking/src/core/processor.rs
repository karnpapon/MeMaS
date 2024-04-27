use opencv::videoio::VideoCapture;
use opencv::{ imgproc, prelude::* };

pub fn get_frame(vid_stream: &mut VideoCapture) -> Option<Mat> {
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
      0.5,
      0.5,
      imgproc::INTER_LINEAR,
    )
    .unwrap();
    Some(reduced)
  }
}