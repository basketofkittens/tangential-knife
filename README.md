# tangential-knife

Tangential knife post processer for Fusion 360.

Based on work by jejmule. https://github.com/jejmule/PostProcessor
  
For use with a Avid EX mill (Centroid Acorn control).
  
Usage/Notes:
* Only tested using "2D Contour" toolpaths with a "tool diameter" of 0.1mm.
* Remove lead-in, lead-out, and chamfer options.
* The G02/G03 feeds are a calculation hack to provide a rotary axis feedrate equivalent to the commanded linear feedrate.
 * There is probably a more graceful way to handle this (eg. inverse time), but this works for me.
* The code can attempt to force G0 rapid moves that are blocked in the free version of Fusion. This is not exhaustively tested, so proceed with caution.