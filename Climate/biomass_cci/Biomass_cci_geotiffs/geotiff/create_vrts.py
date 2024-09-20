import os
import subprocess


if __name__ == "__main__":
    for subdir, _, files in os.walk('.'):
        print(f'processing {subdir}')
        tif_files = [os.path.join(subdir, f) for f in files if f.endswith('.tif')]
        if tif_files:
            tif_pattern = os.path.join(subdir, "*.tif")
            vrt_filename = os.path.join(subdir, os.path.basename(subdir) + '.vrt')
            gdal_command = ['gdalbuildvrt', vrt_filename, tif_pattern]
            subprocess.run(gdal_command)
