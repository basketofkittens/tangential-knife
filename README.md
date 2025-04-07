# tangential-knife

Tangential knife post processer for Fusion 360.

Based on work by jejmule. https://github.com/jejmule/PostProcessor

Tested on an Avid EX mill (Centroid Acorn control).

Usage/Notes:

* Only tested using "2D Contour" toolpaths with lead-in, lead-out, and chamfer options removed. "Tool diameter" of 0.1mm.
    * Sample tool library and toolpath template available in the Profiles folder
* Translations between line segments is done at retract height
* Assumes all cutting will occur in the XY plane.

Post Processor Settings:

* Lift Angle [degrees]
    * Maximum angle at which the blade is turned in the material. Angles strictly greater than this will result in a lift>rotate>plunge cycle. This calculation is applied at the beginning of any non-rapid move.
* Minimum Arc Radius [in or mm]
    * G2/G3 (circular arc) moves below this radius will be approximated by a series of linear moves.
* Minimum Radius [in or mm]
    * G2/G3 (circular arc) moves below this radius will be clipped entirely and replaced with a linear move to the arc's endpoint.
* Use Calculated Angular Feed [boolean]
    * Convert the commanded linear feedrate to an equivalent angular feedrate for G2/G3 (circular arc) moves.
    * This is a calculation hack to provide consistent feedrates on machines that treat any move with a rotary axis as an angular feed (eg. Centroid Acorn).
* Force Rapid Moves [boolean]
    * Attempts to force G0 rapid moves that are disabled in the free version of Fusion 360. This is not exhaustively tested. Use at your own risk.
* Reduce Rotations [boolean]
    * On machines with rotary axis position bounds in the (-360, 360) range, rotary moves will translate linearly from one angle to the next. This often results in G0 rotations greater than 180 degrees. This option will limit G0 rotations to less than 180 degrees. This setting doesn't functionally change anything about how the cuts are commanded, I just hate seeing the C-axis make superfluous rotations.
    * Note: This has only been tried on an Avid EX machine with a Centroid Acorn control and is not exhaustively tested. Use at your own risk.
* Print Debug Strings [boolean]
    * Self explanatory
* Use Global Tolerance [boolean]
    * Overrides the per-feature tolerance settings with the "(Built-in) Tolerance" setting. Used in combination with "Minimum Arc Radius" setting to tune how many linear segments make up a given arc move.

Potential improvements:
* Fix initial position move to be G0 and not G1