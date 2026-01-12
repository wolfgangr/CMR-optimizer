## Why?

This Repo ist the companion to the [QGIS issue #64501:](https://github.com/qgis/QGIS/issues/64501)  
**Estimate Target CRS type and parameters in Georeferencer** #64501

When I was working on the **georeferencing** of scanned maps from **historical atlases**, I found it difficult to **identify** the correct **target** coordinate system aka **CRS**.

To some extent, it is **possible to "bend"** a scan toward a somewhat **misaligned CRS by** insertion of a **transformation**, typically a **polynom** of degree 1 ... 3. QGIS **georeferencer** implements a powerful **least square** algorithm (presumably) including GUI for that task.

However, this approach has a couple of **shortcomings**:
- the higher the polynomial degree of the transformation, the **more matching points** are required
- upon georeferencing several maps of the same source, every map with independent matching points may yield different pseudo-correction of CRS, introducing deviations between maps of the same source, covering the same area, by the process of setting mapping points
- at a given number of matching points with the same amount of error, polynomials of lower degree provide better averaging out of matching errors, while polynoms of higher degree tend towards symptoms of **overfitting**
- polynomials of higher degree tend to "**misbehave**" in areas away from the center, e.g. **at the edges** of the map
- a 3rd deg. polynom might be nice to repair **distortions** introduced by the **book spline** of two-paged maps, which are very common in atlases. But if the polynom's shape is already dominated by the (large) distortion required to align a incorrect CRS, there is **no freedom left** for the small distortion of different shape required to repair book spline effects - and neither "stiffness" to keep the map in shape away from the spline
- **TPS** transformation carries the concept of **overfitting to the extreme**. Providing no averaging at all, it **requires a large number of precise mapping points**. Every mapping point error is forwarded in full scale to the target map.

These shortcomings could be handled in the most precise and efficient way, if we **know the CRS** aka map projection scheme as employed by the original map maker, including it's **parameters** (dependent on the CRS family at hand). The **transformation** function can be set as **stiff** (i. e. low degree) as possible, just to handle residual errors in map making, scanning and matching point placement.

Unfortunately, **most atlases** I found **do not explicitly reveal the CRS** type employed, **nor** their **parameters**. So it's left to insider information, experience or more or less well trained guess work.

## Core concept

So the core **idea** of this repo is to employ the **least square** mechanism probably implemented in the QGIS georeferencer anyway **to estimate type and parameter of the target CRS**.  

I'd expected that this were a challenge completed long ago. So before filing above mentioned qgis github issue, I **searched** the documentation of qgis, the plugin manager, proj and the common internet to avoid reinventing the wheel - but to **no avail**. As of writing, QGIS core team reports to be busy in planing "Release 4.X", so I saw little hope for some asap solution to my feature request. Time to help yourself ;-). 

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
- as of ~ **1850**, most **map sources** (1) are surveyed to < 1km deviation, allowing **pixel precision** in display of maps at continental scale
- the **map makers CRS** is a **deterministic** mathematical model, **knowable** in principle, but **commonly unknown**
- the errors of map making, printing and scanning are not knowable plain **statistical errors**
- we assume our **SOURCE RASTER** (2) as given with quality **beyond our influence**
- established **QGIS georeferencing optimizes** paramters for the **transformation** to align the source raster to an intermediary geotiff file, which is associated (maybe documented in exif inside) to a defined **target CRS** (as a property of said geotiff)
- transformation function and target CRS allow the assesment of **matching error** for any points (expressed as pixel error in source raster space)
- in QGIS georeferencer, the **transformation** is **optimized** by some iterative algorithm minimizing **least square** error sum of the matching points (loop above (3))
- in the extension **proposed here**, **target CRS** is **optimised**  (dottted loop, closing below (3))  by least square **as well** - together or maybe in iterative interactive search with raster alignment transformation

## Choice of Platform








