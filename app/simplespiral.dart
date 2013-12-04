library simplespiral;

import 'dart:math';
import 'dart:html';
import 'dart:convert';
import 'dart:web_gl';
import 'dart:async';
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';

part 'gl_program.dart';

int boundsChange = 100;
CanvasElement canvas = querySelector("#lesson01-canvas");
RenderingContext gl;
SimpleSpiral program;

/// Perspective matrix
Matrix4 pMatrix;

/// Model-View matrix.
Matrix4 mvMatrix = new Matrix4.zero();

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

/**
 * For non-trivial uses of the Chrome apps API, please see the
 * [chrome](http://pub.dartlang.org/packages/chrome).
 * 
 * * http://developer.chrome.com/apps/api_index.html
 */
void main() {
  Matrix4 mvMatrix = new Matrix4.identity();
  gl = canvas.getContext3d();
  if(gl == null) {
    return;
  }
  
  program = new SimpleSpiral();
  
  tick(0);
}

void tick(time) {
  window.requestAnimationFrame(tick);
  frameCount(time);
  program.handleKeys();
  program.animate(time);
  program.drawScene(canvas.width, canvas.height, canvas.width/canvas.height);
}

/**
 * The base for all Learn WebGL lessons.
 */
class SimpleSpiral {
  GlProgram program;
  Buffer triangleVertexPositionBuffer;
  
  SimpleSpiral() {
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

    // bindBuffer() tells the WebGL system the target of future calls
    gl.bindBuffer(ARRAY_BUFFER, triangleVertexPositionBuffer);
    gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList([
           0.0,  1.0,  0.0,
          -1.0, -1.0,  0.0,
           1.0, -1.0,  0.0
        ]), STATIC_DRAW);

    // Specify the color to clear with (black with 100% alpha) and then enable
    // depth testing.
    gl.clearColor(0.0, 0.0, 0.5, 1.0);
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
    //mvPushMatrix();

    //mvMatrix.translate(-1.5, 0.0, -7.0);

    // Here's that bindBuffer() again, as seen in the constructor
    gl.bindBuffer(ARRAY_BUFFER, triangleVertexPositionBuffer);
    // Set the vertex attribute to the size of each individual element (x,y,z)
    gl.vertexAttribPointer(program.attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);
    setMatrixUniforms();
    // Now draw 3 vertices
    gl.drawArrays(TRIANGLES, 0, 3);

    // Finally, reset the matrix back to what it was before we moved around.
    //mvPopMatrix();
  }

  /**
   * Animate the scene any way you like. [now] is provided as a clock reference
   * since the scene rendering started.
   */
  void animate(num now) {}

  /**
   * Handle any keyboard events.
   */
  void handleKeys() {}

  /**
   * Write the matrix uniforms (model view matrix and perspective matrix) so
   * WebGL knows what to do with them.
   */
  setMatrixUniforms() {
    gl.uniformMatrix4fv(program.uniforms['uPMatrix'], false, pMatrix.storage);
    gl.uniformMatrix4fv(program.uniforms['uMVMatrix'], false, mvMatrix.storage);
  }

  /**
   * Added for your convenience to track time between [animate] callbacks.
   */
  num lastTime = 0;
}

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