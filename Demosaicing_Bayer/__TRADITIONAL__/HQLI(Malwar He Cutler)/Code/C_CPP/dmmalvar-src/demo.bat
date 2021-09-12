@echo off
rem Demo script for using dmmalvar
rem Pascal Getreuer 2011

rem Image credits: the test image frog.bmp is by 
rem   John D. Willson, USGS Amphibian Research and Monitoring Initiative
rem   http://armi.usgs.gov/gallery/detail.php?search=Genus&subsearch=Bufo&id=323


echo.
echo +============================================================================+
echo + First, we mosaic the input image "frog.bmp"                                +
echo +============================================================================+

.\mosaic -v -pRGGB frog.bmp frog-m.bmp

echo.
echo.
echo +============================================================================+
echo + Now we run the bilinear and Zhang-Wu demosaicing to create "frog-bl.bmp"   +
echo + and "frog-mal.bmp"...                                                      +
echo +============================================================================+

.\dmbilinear -pRGGB frog-m.bmp frog-bl.bmp
.\dmmalvar -pRGGB frog-m.bmp frog-mal.bmp

echo.
echo.
echo +============================================================================+
echo + The difference between the original and "frog-bl.bmp" is                   +
echo +============================================================================+

.\imdiff frog.bmp frog-bl.bmp

echo.
echo.
echo +============================================================================+
echo + The difference between the original and "frog-mal.bmp" is                  +
echo +============================================================================+

.\imdiff frog.bmp frog-mal.bmp

echo.

pause
