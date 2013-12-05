library simplespiral;

import 'dart:html';
import 'dart:web_gl';
import 'dart:typed_data';
import 'dart:math';

import 'package:vector_math/vector_math.dart';
part 'gl_program.dart';

CanvasElement canvas = querySelector("#lesson01-canvas");
RenderingContext gl;
Lesson1 lesson;

void main() {
  print(querySelector("#degrees").getAttribute("value"));
  mvMatrix = new Matrix4.identity();
  sMatrix = new Matrix4.identity();
  // Nab the context we'll be drawing to.
  gl = canvas.getContext3d();
  if (gl == null) {
    return;
  }
  lesson = new Lesson1();
  
  querySelector("#update").onClick.listen(
      (event) => lesson.update()
      );

  // Start off the infinite animation loop
  tick(0);
}

/**
 * This is the infinite animation loop; we request that the web browser
 * call us back every time its ready for a new frame to be rendered. The [time]
 * parameter is an increasing value based on when the animation loop started.
 */
tick(time) {
  //window.requestAnimationFrame(tick);
  //frameCount(time);
  lesson.handleKeys();
  lesson.animate(time);
  lesson.drawScene(canvas.width, canvas.height, canvas.width/canvas.height);
}

/// Perspective matrix
Matrix4 pMatrix;

/// Model-View matrix.
Matrix4 mvMatrix;

Matrix4 sMatrix;

List<Matrix4> mvStack = new List<Matrix4>();

/**
 * Add a copy of the current Model-View matrix to the the stack for future
 * restoration.
 */
mvPushMatrix() => mvStack.add(new Matrix4.copy(mvMatrix));

/**
 * Pop the last matrix off the stack and set the Model View matrix.
 */
mvPopMatrix() => mvMatrix = mvStack.removeLast();

/// FPS meter - activated when the url parameter "fps" is included.
const num ALPHA_DECAY = 0.1;
const num INVERSE_ALPHA_DECAY = 1 - ALPHA_DECAY;
const SAMPLE_RATE_MS = 500;
const SAMPLE_FACTOR = 1000 ~/ SAMPLE_RATE_MS;
int frames = 0;
num lastSample = 0;
num averageFps = 1;
DivElement fps = querySelector("#fps");

void frameCount(num now) {
  frames++;
  if ((now - lastSample) <  SAMPLE_RATE_MS) return;
  averageFps = averageFps*ALPHA_DECAY + frames*INVERSE_ALPHA_DECAY*SAMPLE_FACTOR;
  fps.text = averageFps.toStringAsFixed(2);
  frames = 0;
  lastSample = now;
}
bool trackFrameRate = false;

class Lesson1 {
  GlProgram program;
  List points;

  Buffer triangleVertexPositionBuffer, squareVertexPositionBuffer;

  Lesson1() {
    program = new GlProgram('''
          precision mediump float;

          void main(void) {
              gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
          }
        ''','''
          attribute vec3 aVertexPosition;

          uniform mat4 uMVMatrix;
          uniform mat4 uPMatrix;

          void main(void) {
              gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
          }
        ''', ['aVertexPosition'], ['uMVMatrix', 'uPMatrix']);
    gl.useProgram(program.program);

    // Allocate and build the two buffers we need to draw a triangle and box.
    // createBuffer() asks the WebGL system to allocate some data for us
    triangleVertexPositionBuffer = gl.createBuffer();
    
    points = makeLogarithmicSpiral(2000.0, 0.05, 0.5, 0.05);
    
    //print(points);

    // bindBuffer() tells the WebGL system the target of future calls
    gl.bindBuffer(ARRAY_BUFFER, triangleVertexPositionBuffer);
    gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(points), STATIC_DRAW);
    

    // Specify the color to clear with (black with 100% alpha) and then enable
    // depth testing.
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
  }

  void drawScene(num viewWidth, num viewHeight, num aspect) {
    // Basic viewport setup and clearing of the screen
    gl.viewport(0, 0, viewWidth, viewHeight);
    gl.clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
    gl.enable(DEPTH_TEST);
    gl.disable(BLEND);

    // Setup the perspective - you might be wondering why we do this every
    // time, and that will become clear in much later lessons. Just know, you
    // are not crazy for thinking of caching this.
    pMatrix = makePerspectiveMatrix(45.0, aspect, 0.1, 100.0);

    // First stash the current model view matrix before we start moving around.
    mvPushMatrix();

    mvMatrix.translate(0.0, 0.0, -7.0);
    //mvMatrix.scale(0.00000005, 0.000000005, 1.0);

    // Here's that bindBuffer() again, as seen in the constructor
    gl.bindBuffer(ARRAY_BUFFER, triangleVertexPositionBuffer);
    // Set the vertex attribute to the size of each individual element (x,y,z)
    gl.vertexAttribPointer(program.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);
    setMatrixUniforms();
    // Now draw 3 vertices
    //gl.drawArrays(LINE_STRIP, 0, (points.length~/3.0)-1);
    gl.drawArrays(LINE_STRIP, 0, (points.length~/3.0)-1);

    // Finally, reset the matrix back to what it was before we moved around.
    mvPopMatrix();
  }

  /**
   * Write the matrix uniforms (model view matrix and perspective matrix) so
   * WebGL knows what to do with them.
   */
  setMatrixUniforms() {
    gl.uniformMatrix4fv(program.uniforms['uPMatrix'], false, pMatrix.storage);
    gl.uniformMatrix4fv(program.uniforms['uMVMatrix'], false, mvMatrix.storage);
  }

  void animate(num now) {
    // We're not animating the scene, but if you want to experiment, here's
    // where you get to play around.
  }

  void handleKeys() {
    // We're not handling keys right now, but if you want to experiment, here's
    // where you'd get to play around.
  }
  
  void update() {
    double theta = double.parse((querySelector("#degrees") as InputElement).value);
    double resolution = double.parse((querySelector("#resolution") as InputElement).value);
    double A = double.parse((querySelector("#a") as InputElement).value);
    double B = double.parse((querySelector("#b") as InputElement).value);
    
    List p = makeLogarithmicSpiral(theta, resolution, A, B);
    
    //print(p);
    print(theta);
    
    this.points = p;
    gl.bindBuffer(ARRAY_BUFFER, triangleVertexPositionBuffer);
    gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(points), STATIC_DRAW);
    
    tick(lastTime+1);
  }
  
  num lastTime = 0;
}

List toPolar(double r, double theta) {
  return [r*cos(theta), r*sin(theta), 0.0];
}

double toRadians(double d) {
  return PI*d/180.0;
}

double distance(double x1, double y1, double x2, double y2) {
  return sqrt(pow(x1-x2, 2) + pow(y1-y2, 2));
}

/**
 * Approximates the Lambert_W_Function
 *  using Newtons Method
 */
double w0(double x, [ double err = .000001]) {
  double w = x;
  while(1==1) {
    double ew = exp(w);
    double wNew = w- (w*ew-x) / (w * ew + ew);
    if((w - wNew).abs() <= err) {
      break;
    }
    w = wNew;
  }
  return w;
}

List makeLogarithmicSpiral(double theta, [double resolution=1.0, double a=1.0, double b=1.0]) {
  List points = new List();
  
  double cur_theta = 0.0, prevx=0.0, prevy=0.0, prev_d=0.0, d_theta=1.0;
  
  while(cur_theta < theta) {
    double this_theta = toRadians(cur_theta);
    double r = a*pow(E, b*this_theta);
    List p = toPolar(r, this_theta);
    points.addAll(p);
    
    //d_theta *= 1 - w0(b*resolution/a)/b;
    // If the distance between this point and the next is to big,
    //  start making smaller increments
    double d = distance(prevx, prevy, p[0], p[1]);
    if(d >= resolution) {
      d_theta *= w0(b*resolution/a)/b;
      print(d_theta);
    }
    cur_theta += d_theta;
    prevx = p[0];
    prevy = p[1];
  }
  
  /*for(double i=0.0; i < theta*resolution; i++) {
    double this_theta = toRadians(i/resolution);
    double r = a*pow(E, b*this_theta);
    List p = toPolar(r, this_theta);
    points.addAll(p);
    
    print(distance(prevx, prevy, p[0], p[1]).toString());
  }*/
  
  return points;
}
