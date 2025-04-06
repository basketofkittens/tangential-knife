# tangential-knife

Tangential knife post processer for Fusion 360.

Based on work by jejmule. https://github.com/jejmule/PostProcessor

For use with a Avid EX mill (Centroid Acorn control).

Usage/Notes:

* Only tested using "2D Contour" toolpaths with a "tool diameter" of 0.1mm.
* Remove lead-in, lead-out, and chamfer options from the toolpath settings.
* Translations between line segments is done at retract height
* The G02/G03 feeds are a calculation hack to provide a rotary axis feedrate equivalent to the commanded linear feedrate.
    * There is probably a more graceful way to handle this (eg. inverse time), but this works for me.
    * This feed conversion can be overwritten using a Post Processor Options flag.
* The code can attempt to force G0 rapid moves that are blocked in the free version of Fusion. This is not exhaustively tested, so proceed with caution.

Potential improvements:
* Remove excess C-axis rotations
    * Rotation is bounded to (-360, 360) and the control will rotate "linearly" to a new angle. This will result real-life rotations of greater than 360 degrees.
* Fix initial position move to be G0 and not G1
    * Not sure I care enough to fix this