/**
  Tangential knife post processer for Fusion 360.
  
  Based on work by jejmule. https://github.com/jejmule/PostProcessor
  
  For use with a Avid EX mill (Centroid Acorn control).
  
  Usage/Notes:
  - Only tested using "2D Contour" toolpaths with a "tool diameter" of 0.1mm.
  - Remove lead-in, lead-out, and chamfer options.
  - The G02/G03 feeds are a calculation hack to provide a rotary axis feedrate equivalent to the commanded linear feedrate.
      - There is probably a more graceful way to handle this (eg. inverse time), but this works for me.
  - The code can attempt to force G0 rapid moves that are blocked in the free version of Fusion. This is not exhaustively tested, so proceed with caution.
  
*/

description = "Tangential Rotary Blade";
vendor = "KBuchka";
vendorUrl = "kbuchka@gmail.com";
certificationLevel = 2;

longDescription = "Tangential Rotary Blade support based on Jejmule's post.";

extension = "nc";
setCodePage("ascii");

capabilities = CAPABILITY_MILLING | CAPABILITY_MACHINE_SIMULATION;
allowHelicalMoves = false;
tolerance = spatial(0.3, MM);

minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowedCircularPlanes = 1 << PLANE_XY;

// user-defined properties
properties = {
  liftAtCorner: {
      title: "Lift Angle", 
      description: "Maximum angle at which the blade is turned in the material. If the angle is larger the blade is lifted and rotated.", 
      type: "angle", 
      value: 0.5
  },
  minLinearRadius: {
      title: "Minimum Radius", 
      description: "Absolute minimum radius allowable. Radii smaller than this will be clipped entirely with a linear move.", 
      type: "number", 
      value:5
  },
  minArcRadius: {
      title: "Minimum Arc Radius", 
      description: "Radii smaller than this will be approximated with discrete linear moves.", 
      type: "number", 
      value:10
  },
  usePostTolerance: {
      title: "Use Global Tolerance", 
      description: "Override operation-specific tolerances for linearizations.", 
      type: "boolean", 
      value: true
  },
  forceRapids: {
      title: "Force Rapid Moves", 
      description: "Un-nerf the free version of Fusion by trying to force G0 rapid moves instead of G1 rapid moves. USE AT YOUR OWN RISK.", 
      type: "boolean", 
      value: true
  },
  useCalcAngularFeed: {
      title: "Use calculated angular feed",
      description: "Enabling this will compute an angular feedrate for G02/03 moves that is equivalent to the specified linear feedrate. Used for controls that feed rotary axes in angle/time rather than distance/time (eg. Centroid Acorn).",
      type: "boolean",
      value: true
  }
};

var WARNING_WORK_OFFSET = 0;
var WARNING_COOLANT = 1;

var gFormat = createFormat({prefix:"G", decimals:0, width:2, zeropad:true});
var mFormat = createFormat({prefix:"M", decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var abcFormat = createFormat({decimals:3, forceDecimal:true})//, scale:DEG});
var feedFormat = createFormat({decimals:(unit == MM ? 2 : 3)});

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({prefix:"Z"}, xyzFormat);

var cOutput = createVariable({prefix:"C"}, abcFormat);

var iOutput = createReferenceVariable({prefix:"I"}, xyzFormat);
var jOutput = createReferenceVariable({prefix:"J"}, xyzFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91

var sequenceNumber = 0;

//specific section for Tangential Rotary Blade
var c_rad = toRad(0);  // Current A axis position
var isRapid = false;

/**
 Update C position for Tangential Rotary Blade
 */
 function updateC(target_rad) {
  var delta_rad = (target_rad-c_rad) //% (2*Math.PI)

  //next segment is colinear with current segment. Do nothing
  if (delta_rad % (2*Math.PI) == 0){
    return;
  }
  
  // Angle between segments is larger than maximum angle. Lift blade, rotate, and plunge back down
  if (Math.abs(delta_rad) > toRad(getProperty("liftAtCorner"))) { 
    moveUp();
    gMotionModal.reset();
    writeBlock(gMotionModal.format(0), cOutput.format(toDeg(target_rad)));
    moveDown();
    c_rad = target_rad;
  }
  else {  // Angle between segments is smaller than maximum angle. Rotate blade in material
    writeBlock(gMotionModal.format(1), cOutput.format(toDeg(target_rad)));
    c_rad = target_rad;
  }
  
 }

/**
 Move cutter up to retract height
 */
 function moveUp() {
   retractPos = getCurrentPosition();
   onRapid(retractPos.x,retractPos.y,getParameter("operation:retractHeight_value"));
 }

/**
 Move cutter down to work height
 */
 function moveDown() {
  plungePos = getCurrentPosition();
  onRapid(plungePos.x,plungePos.y,plungePos.z);
 }

/**
  Writes the specified block.
*/
function writeBlock() {
  if (!isRapid || !getProperty("forceRapids")) { // Not a rapid move, not forcing rapids
    writeWords2("N" + sequenceNumber, arguments);
  } else {  // Rapid move 
    isRapid = false;
    newStr = formatWords(arguments).replace("G01", "G00")
    writeln("N" + sequenceNumber + " " + newStr);
  }
  sequenceNumber += 1;
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln("(" + text + ")");
}

function onOpen() {
  if (programName) {
    writeComment(programName);
  }
  if (programComment) {
    writeComment(programComment);
  }

  //writeBlock(gAbsIncModal.format(90));
  //writeBlock(gFormat.format(64)); //G64 look forward option

}

function onSection() {
  if (!isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
    error(localize("Tool orientation is not supported."));
    return;
  }
  setRotation(currentSection.workPlane);

  if (currentSection.workOffset != 0) {
    warningOnce(localize("Work offset is not supported."), WARNING_WORK_OFFSET);
  }
  if (tool.coolant != COOLANT_OFF) {
    warningOnce(localize("Coolant not supported."), WARNING_COOLANT);
  }

  // Zero C-axis rotation
  writeBlock(gFormat.format(0),cOutput.format(0));
  feedOutput.reset();
}

function onRapid(_x, _y, _z) {
  isRapid = true;
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  
  if (x || y || z) {
    writeBlock(gMotionModal.format(0), x, y, z);
    feedOutput.reset();
  }
}

function onLinear(_x, _y, _z, feed) {
  var start = getCurrentPosition();
  var target = new Vector(_x,_y,_z);
  var direction = Vector.diff(target,start);
  //compute orientation of the upcoming segment
  var orientation_rad = direction.getXYAngle();
  
  // Gate C-axis rotation if move is purely in Z.
  if (!(start.x == _x && start.y == _y)) {
    updateC(orientation_rad);
  }
  
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  if (x || y) {
    writeBlock(gMotionModal.format(1), x, y, feedOutput.format(feed));
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  var radius = getCircularRadius();

  if (radius <= getProperty("minLinearRadius")) {
    // Replace the arc move with a simple linear move to the endpoint.
    onLinear(x, y, x, feed);
    return;
  }
  
  if (radius <= getProperty("minArcRadius")) {
    var t = tolerance;
    if (hasParameter("operation:tolerance") && !getProperty("usePostTolerance")) {
      t = getParameter("operation:tolerance");
    }
    // Replace the arc move with discrete linear steps
    linearize(t);
    return;
  }

  // one of X/Y and I/J are required and likewise

  switch (getCircularPlane()) {
  case PLANE_XY:
    var arcLength = getCircularArcLength();
    var arcAngle = getCircularSweep();
    
    var start = getCurrentPosition();
    var OD = start;  //vector at current position
    
    var OC = getCircularCenter();
    
    var Z = new Vector(0,0,clockwise ? 1 : -1);  //vector normal to XY plane
    var CD = Vector.diff(OD,OC); //OD-OC = CO+OD = CD -> radius vector from arc center to current position
    var tangent = Vector.cross(CD,Z); //tangent vector to circle in the direction of motion
    var start_dir = tangent.getXYAngle(); //direction of the motion at starting point
    updateC(start_dir);

    
    if(clockwise){
      c_rad -= arcAngle
    }
    else {
      c_rad += arcAngle
    }
    
    var outputFeed = feed;
    if (getProperty("useCalcAngularFeed")) {
        outputFeed = calcAngularFeed(arcLength, arcAngle, feed);
    }
    
    writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), cOutput.format(toDeg(c_rad)), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(outputFeed));
    break;
  default:
    var t = tolerance;
    if (hasParameter("operation:tolerance")) {
      t = getParameter("operation:tolerance");
    }
    linearize(t);
  }
}

// Return the feed in degrees/time to hit the desired linear feedrate
function calcAngularFeed(arcLength, arcAngle, linearFeed) {
    travelTime = arcLength/linearFeed;
    return toDeg(arcAngle)/travelTime;
}

function onSectionEnd() {
  moveUp();
  writeBlock(gFormat.format(0),cOutput.format(0));
}

function onClose() {

}