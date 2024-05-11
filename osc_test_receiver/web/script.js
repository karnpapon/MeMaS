//font for WEBGL
// var robotoFont;
// var dotId = 0;

var rotating = true;

// var orbits = [];
// var dotsData = [];

function setup() {
  createCanvas(windowWidth, windowHeight, WEBGL);
  // textFont(robotoFont);
  textFont('Roboto');
  textStyle(NORMAL);
  background(0);
  strokeWeight(4);

  // let orbit1 = new Orbit(0, 0, 0, 0.5, 0.5, 0.5);
  // orbit1.obj.push(new Dot(0, 0));
  // orbits.push(orbit1);
  // let orbit2 = new Orbit(90, 45, 0);
  // orbit2.obj.push(new Dot(0, 0));
  // orbits.push(orbit2);
}

function draw() {
  angleMode(DEGREES);
  background(0);
  orbitControl();

  let len = 200;
  fill("white");
  stroke("white");
  sphere(2);
  stroke("red");
  line(0, 0, 0, len, 0, 0);
  // text("x", len, 0);
  stroke("green");
  line(0, 0, 0, 0, len, 0);
  // text("y", 0, len);
  push();
  rotateX(90);
  stroke("yellow");
  line(0, 0, 0, 0, len, 0);
  // text("z", 0, len);
  pop();

  // dotsData = [];

  // orbits.forEach((o) => o.draw());

  textSize(14);
  // push();
  // for (let i = 0; i < 2; i++) {
  //   let yPos = -(windowHeight / 2) + 15;
  //   for (let i = 0; i < dotsData.length; i++) {
  //     let [id, pos, pos3d] = dotsData[i];
  //     let [x1, y1, z1] = [
  //       pos[0].toFixed(0),
  //       pos[1].toFixed(0),
  //       pos[2].toFixed(0),
  //     ];
  //     let [x2, y2, z2] = [
  //       pos3d.x.toFixed(0),
  //       pos3d.y.toFixed(0),
  //       pos3d.z.toFixed(0),
  //     ];
  //     text(
  //       `${id}: (${x1}, ${y1}, ${z1}) -> (${x2}, ${y2}, ${z2})`,
  //       -windowWidth / 2 + 5,
  //       yPos
  //     );
  //     yPos += 18;
  //   }

  //   rotateX(-90);
  // }
  // pop();
}

function mouseClicked() {
  // controls.mousePressed();
}

function keyPressed() {
  // controls.keyPressed(keyCode);
  // if (keyCode === 32) {
  //   rotating = !rotating;
  // }
}

// class Orbit {
//   constructor(x, y, z, xr, yr, zr) {
//     this.obj = [];
//     this.currentRot = [x ? x : 0, y ? y : 0, z ? z : 0];
//     this.rot = [xr ? xr : 0, yr ? yr : 0, zr ? zr : 0];
//   }

//   draw() {
//     push();

//     if (rotating) {
//       this.currentRot[0] += this.rot[0];
//       this.currentRot[1] += this.rot[1];
//       this.currentRot[2] += this.rot[2];
//     }

//     rotateY(this.currentRot[1]);
//     rotateX(this.currentRot[0]);
//     rotateZ(this.currentRot[2]);

//     noFill();
//     stroke("white");
//     ellipse(0, 0, 300, 300);

//     for (let i = 0; i < this.obj.length; i++) {
//       let o = this.obj[i];
//       o.draw();
//       dotsData.push([o.id, o.getPosition(), this.#get3DPos(o)]);
//     }

//     pop();
//   }

//   #get3DPos(o) {
//     let [x, y, z] = o.getPosition();
//     let w = 0;
//     let rotX = (this.currentRot[0] * PI) / 180;
//     let rotY = (this.currentRot[1] * PI) / 180;
//     let rotZ = (this.currentRot[2] * PI) / 180;

//     let rotation = Quaternion.fromEuler(rotZ, rotX, rotY, "ZXY").conjugate();
//     [x, y, z] = rotation.rotateVector([x, y, z]);

//     return createVector(x, y, z);
//   }
// }

// class Dot {
//   constructor(angle) {
//     this.id = ++dotId;
//     this.x = cos(angle) * 150;
//     this.y = sin(angle) * 150;
//   }

//   draw() {
//     push();
//     fill("gray");
//     translate(this.x, this.y);
//     noStroke();
//     sphere(15);
//     pop();
//   }

//   getPosition() {
//     return [this.x, this.y, 0];
//   }
// }

function map_value( value,in_min, in_max, out_min, out_max) {
  return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

window.onload = function (event) {
  var oscPort = new osc.WebSocketPort({
    url: "ws://localhost:8081",
    metadata: true,
  });

  oscPort.open();

  oscPort.on("message", function (oscMsg) {
    
    const incoming = {
      rotX: map_value(oscMsg.args[0].value, 0, 127, 0, 360),
      rotY: map_value(oscMsg.args[1].value, 0, 127, 0, 360),
      rotZ: map_value(oscMsg.args[2].value, 0, 127, 0, 360),
    };
    console.log("quatoer", incoming)

    Quaternion.fromEulerLogical(incoming.rotZ, incoming.rotX, incoming.rotY, 'ZXY');
  });
};
