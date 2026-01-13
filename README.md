## Why?

This Repo ist companion to [QGIS issue #64501:](https://github.com/qgis/QGIS/issues/64501)  
**Estimate Target CRS type and parameters in Georeferencer** #64501

When I was working on the **georeferencing** of scanned maps from **historical atlases**, I found it difficult to **identify** the correct **target** coordinate system aka **CRS**.

To some extent, it is **possible to "bend"** a scan toward a somewhat **misaligned CRS by** insertion of a **transformation**, typically a **polynom** of degree 1 ... 3. QGIS **georeferencer** implements a powerful **least square** algorithm (presumably) including GUI for that task.

However, this approach has a couple of **shortcomings**:
- the higher the polynomial degree of the transformation, the **more matching points** are required
- upon georeferencing several maps of the same source, every map with independent matching points may yield different pseudo-correction of (maybe genuinly the identical) CRS, introducing deviations between maps of the same source, covering the same area, by the process of setting mapping points
- at a given number of matching points with the same amount of error, polynomials of **lower degree** provide **better averaging out** of matching errors, while polynoms of higher degree tend towards symptoms of **overfitting**
- polynomials of higher degree tend to "**misbehave**" in areas away from the center, e.g. **at the edges** of the map
- a 3rd deg. polynom might be nice to repair **distortions** introduced by the **book spline** of two-paged maps, which are very common in atlases. But either-or: If the polynom's shape is already dominated by the (large in amount and lateral extent) distortion required to align an incorrect CRS, there is **no freedom left** for the small and localized distortion of different shape required to repair book spline effects - and neither "stiffness" to keep the map in shape away from the spline
- **TPS** transformation carries the concept of **overfitting to the extreme**. Providing no averaging at all, it **requires a large number of precise mapping points**. Every mapping point error is forwarded in full scale to the target map.

These shortcomings could be handled in the most precise and efficient way, if we **knew the CRS** aka map projection scheme as employed by the original map maker, including it's **parameters** (dependent on the CRS family at hand). The **transformation** function then could be set as **stiff** (i. e. low polynomial degree) as possible, just to handle residual errors in map making, scanning and matching point placement.

Unfortunately, **most atlases** I found **do not explicitly reveal the CRS** type employed, **nor** their **parameters**. So it's left to insider information, experience or more or less well trained guess work.

## Core concept

So the core **idea** of this repo is to employ the **least square** mechanism probably implemented in the QGIS georeferencer anyway **to estimate type and parameter of the target CRS**.  

I'd expected that this were a challenge completed long ago. So before filing above mentioned qgis github issue, I **searched** the documentation of qgis, the plugin manager, proj and the common internet to avoid reinventing the wheel - but to **no avail**. As of writing, QGIS core team reports to be focussed to "Release 4.X". I saw little hope to expect some asap solution to my feature request. Perfect time to help yourself ;-) . 

## Data flow

```
(1) precise survey map data
 ▼  map maker's choice of CRS including parameters
 ▼  map making and printing errors
 ▼  scanning errors
(2) SOURCE RASTER - - - - - - - - - - - - - - - - + - <- matching points (raster pixel <-> target CRS)
 ▼  raster alignment  <- transform. parameters    |
(3) aligned geotiff                    ▲          ▼
 ▼  target CRS        < .  .  .  .  .  +          |
 ▼  map point error (least square) - - ▲ - + - <- +  
 ▼  QGIS project CRS
(4) QGIS map canvas image
```
Assumptions:
- as of ~ **1850**, most **map sources** (1) are surveyed to < 1km deviation, sufficient for **pixel precision** in display of maps at continental scale even today
- the **map makers CRS** is a **deterministic** mathematical model, **knowable** in principle, but **commonly unknown**
- the errors of map making, printing and scanning are not knowable plain **statistical errors**
- we consider our **SOURCE RASTER** (2) as given, with quality **beyond our influence**
- established **QGIS georeferencing optimizes** paramters for the **transformation** to align the source raster to an intermediary geotiff file, which is associated (maybe documented in exif inside) to a defined **target CRS** (as a property of said geotiff)
- transformation function and target CRS allow the assesment of **matching error** for any points (expressed as pixel error in source raster space)
- in QGIS georeferencer, the **transformation** is **optimized** by some iterative algorithm minimizing **least square** error sum of the matching points (loop closing above (3))
- in the extension **proposed here**, **target CRS** is **optimised**  (dottted loop, closing below (3))  by least square **as well** - together or maybe in iterative interactive search with raster alignment transformation

## Choice of Platform

I know that `QGIS` essentially is a `python` project. But my experience is still well trained in `PERL` .  
Preliminary research suggested and experience confimed that most of the critical tasks ist performed by `libproj` and some generic least square optimizer (`levmar in the light of PERL resources`). Both libraries are available in `python` as well. Maybe, in numpy / scipy there are even better implementations of least square available.  

`levmar` in `PERL` interfaces in `PDL` aka 'PERL data language' variables - an implementation of matrix calculus, allegedly competing on par with frameworks such as `matlab` or `octave`. Look for `python` equivalents in the realms of `sciPy` and/or `numpy`.

The rest is "glue code" - simple craftswork. It was quite clear that a first proof of concept would require complete refacturing anyway. Tedious qgis and GUI integration is beyond the scope of a proof of concept, anyway.

## Maturity and usability

During develoment, it turned out that the integration in the **georeferencer's GUI is not that paramount** than initially expected.  
The **scripts** in this directory can be **run** from console **against some `points` file** produced by the georeferencer without even closing the georeferencer UI.  
The CRS and parameters given can simply entered as **custom CRS in the georeferencer** transformation window.  
Point match errors are updated on the fly then, not even requiring a gdal run to produce a transformed geotiff.  
An **iterative interactive workflow** (limited to the CRS covered by my scripts) is already **possible**.  

There is no configuration scheme yet - any **changes** are to made in the **source**.  
A particular **quirk** is the refusal of the algorithm to converge at helmert **rotation**.  
So I just added a `$rot=0` line, which may be commented out if you want to dig deeper on that issue.

## Usage

- Perform a **georeferencing** as usual and as documented in QGIS manual.  
- Select some **arbitrary target CRS** and place (a gratitious number of) **match points**.
- In a console, select the **script** resembling the CRS family of choice.  
- Just call it with the **point file** (may be including path) **as parameter**.  
- If you are lucky, the algorithm **converges**. The script then displays (among else) a square sum of pixel error and estimates for all helmert and CRS parameters, including a translation into **`proj` syntax**, that might immediately be entered as **custom CRS**.  
- **Change the target CRS** in the georeferencer's setting window according to your needs, findings, guesses, curiosity or your plan to explore CRS.
- Iteratively explore and refine.

There is a **Readme.md** in the **image subdirectory** of this repo.  
It comments a couple of images collected during the development of the scripts and may thus serve as skd of **preliminary manual**.

## Code genalogy

The current crude alpha hack at hand implements every family of CRS in different script, referred to by its name.

Drafting started with `parse_points_to_fit_eqdc.pl`.  
I assumed **rotation** in helmert to be **collinear** with **conical lon_0** in conical projections.
So, this code was written with transformation code restricted to **shift/scale** - still in **plain perl**.

The next step was `parse_points_to_fit_laea.pl`. I expected rotation as a essential degree of freedom, to be allowed to move for a perfect fit for a CRS to be optimized.  
Assuming that matrix calculus was the proper way to implement this, `levmar` forcing matrix PDL interface, `proj` threatening severe performance penalties on repeted pointwise calls, and PDL was on my "nice-to-be-learned"-list anyway, I **rewrote** the whole chain **to matrix PDL**.

Ironically, just to find that in 3.5 out of 4 CRS families, the algorithm **does not converge on rotation**. Further scrutiny is still on the TBD-List.  
(Yes, I remember one successful convergence on rotation, but have to admit that I can't reconstruct the details any more)...   
So all successful optimisation is a variant of `parse_points_to_fit_laea.pl`.  
Actually, as a simple diff may reveal, descendants essentially are a bare copy, complemented by minor modification to allow for different parameter syntax of different CRS. And some ballast of variable names referring to CRS - that begs to be thrown overboard on the very first refacturing.

## code walkthrough

So let's document `parse_points_to_fit_laea.pl` as the template.  
The first 16 lines comprise dreaded perl 'syntactic sugar' or include external libraries.  
Most of them are documented in CPAN. Most of them are available in debian trixie repo.

The least square algorithm `PDL::Fit::Levmar` ist the only exception, that has to be built by CPAN / CPANM. As I found during testing, It ist missing linalg dependency, restricting usable features. still on TBD....

Constant Pi and 'WGS 84' as standard frame of reference close the prelude.

The dreaded `PERL` 'diamond-operator' `<>` reads the file supplied as first argument to the script line-by-line, supposed to be a *.points file as produced by QGIS-georeferencer. We are in early alphy, so there is only limited check for plausibility.    
Some regexp, some # and dots printed to the console, and a bunch of csv lines splitted to an array of array-refs (aka 2D array), containing our map points.

In line 45, we rehash the array (python pro's might think of 'dictonary' instead), so we can add additional fields without keeping track of array indices.

Line 55 ff extracts the CRS definition stored in WKT-syntax in the first line of our point file.  
We instruct LibProj to map back our matching points from our preliminary CRS (considered as arbitrary aka close to irrelvant) back to plain lat/lon, as defined in $CRS_lat_lon. We store those tagged as 'lat' and 'lon' in our central structure aka `%d_hash`.

Line 71 ... 80 deliver some debug output essential for development, but nasty for usage. Gracefully ignoring the rules for structured programming, we surround it with some nasty "goto" to skip it - or to keep it by commenting out the goto-clause.

Line 85 ... 107 collect and debug a couple of statistics for our matching points in lat/lon coordinate space.

Line 111 is essential for **implementing a specific CRS**. Syntactically, it's a **template** to be reused by printf / **sprintf** widely known from C and other languages.  
The following lines provide estimates referring to this CRS to be supplied to the least square optimizer. Just recall that these optimizer may just find local optima, but not transcede barriers to other realms of may be better global optima. So, the calculation of reasonable starting points might turn out as paramount for a successful search for "best CRS". In our pre-alpha-stage, we are happy to start our optimizer towards any result at all.

Line 122 inserts the start value into proj syntax, and line 125 calculates eatimates in the estimated CRS for all match points.  
Employing the same patterns than above, we collect those estimates to our data hash. Any refacturing might try to separate the code from prameters, and provide reusable code for different scopes.  
Line 158 ff performs the same calculations for match points in source raster.
Line 180 ff performs the same calculations for match points after Helmert transform (or may be other transformation, e.g. higher degree polynomials, later on).

197 ff is a similiar scheme of debug, written to be activated / deactivated by a simple comment in front of the `goto:`-line.
























