"""Description of process ing `biomass_cci_README.txt`."""
import logging

from ecoshard import taskgraph
from osgeo import gdal
from osgeo import osr
import ecoshard
import numpy

import ecoshard.geoprocessing as geoprocessing
import ecoshard.geoprocessing.routing as routing
from ecoshard import taskgraph


gdal.SetCacheMax(2**27)

logging.basicConfig(
    level=logging.DEBUG,
    format=(
        '%(asctime)s (%(relativeCreated)d) %(processName)s %(levelname)s '
        '%(name)s [%(funcName)s:%(lineno)d] %(message)s'))
LOGGER = logging.getLogger(__name__)
logging.getLogger('taskgraph').setLevel(logging.WARN)
logging.getLogger('ecoshard.geoprocessing').setLevel(logging.WARN)


def main():
    """Entry point."""
    vector_path = "./Biomass_cci_geotiffs/Pilot_scapes"
    pass


if __name__ == '__main__':
    main()
