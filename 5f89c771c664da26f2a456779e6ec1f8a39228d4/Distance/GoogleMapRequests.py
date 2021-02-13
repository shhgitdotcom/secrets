import csv
import urllib.request
import json
import time
import datetime
import googlemaps
import os
import re
from typing import *
import io
import numpy as np


def get_data_path(filename: str):
    """
    Get the Data Path
    :param filename: the file name to be read
    :return: the path to "data" directory which the file is located
    """
    dir_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(dir_path, filename)


def load_data(api_key, Building_Names, Building_MetaData):
    """
    Read from the file Building_Names and use google api to get Building Meta Data
    :param api_key: the api key for google api
    :param Building_Names: the file to be read
    :param Building_MetaData: Meta Data related to Google Geocoding API
    :return: void
    """
    print("Start Loading Data")
    with open(get_data_path(Building_Names)) as f:
        buildings = list(
            json.load(f).keys())  # store all the buildings in a list

    # use regex to set the building names to desired format
    pattern = "[^()]*"
    x = re.compile(pattern)
    new_buildings = []
    for b in buildings:
        match = x.search(b)

        # get rid of the double space and get all the lower case names
        building = match.group(0).strip().lower().replace("  ", " ")

        new_buildings.append(building)

    # get the coordinate of each building and save to a json file
    with open(get_data_path(Building_MetaData), 'w') as f:
        jdata = {}
        for count, i in enumerate(new_buildings):
            # get raw data
            raw = get_raw_coordinate(api_key, i)

            # verify the address
            if raw == None:
                continue

            # use the place name as key to store the building information
            jdata[i] = raw

            print(count)

        json.dump(jdata, f)


def get_raw_coordinate(api_key, bldg):
    """
    Use googlemaps api to get the meta data of each building
    :param api_key: the api key for google api
    :param bldg: building name at UVa
    :return: None if the address does not exist, MetaData if exists
    """
    gm = googlemaps.Client(key=api_key)
    geocode_result = gm.geocode('{},UVA'.format(bldg))

    # verify if the this address is in UVA, because if the coordinate not exist, it will redirect to UVa coordinates
    lat = geocode_result[0]['geometry']['location']['lat']
    lng = geocode_result[0]['geometry']['location']['lng']
    if float(lat) == 38.0335529 and float(lng) == -78.5079772:
        return None

    return geocode_result


def create_distance_matrix(api_key, Building_MetaData, Building_Array, Time_Matrix, Distance_MetaData):
    """
    Read from Building_MetaData and use google api to create the following files: Building_Array, Time_Matrix, Distance_MetaData
    :param api_key: the api key for google api
    :param Building_MetaData: Building_MetaData
    :param Building_Array: the 1d array serving as a dictionary which uses index as key and the building names as value
    :param Time_Matrix: the 2d array serving as a dictionary which contains the time it takes to walk from one building to another. 
                        Use Building_Array to look up the name of the building in each index
    :param Distance_MetaData: Meta Data related to Google Distance Matrix API
    :return: void
    """
    print("Start Creating Distance Matrix :)")
    # get all the building names in an sorted order from the Building_MetaData
    with open(get_data_path(Building_MetaData), "r") as f:
        data = json.load(f)
        keys = sorted(list(data.keys()))

    # save the building array to a file
    json.dump(keys, open(get_data_path(Building_Array), 'w'))

    # Now get the Distance Meta Data
    jdata = {}
    count = 0
    array = np.zeros((len(keys), len(keys)), dtype=np.int32)

    for i in range(len(keys)):
        for j in range(i + 1, len(keys)):
            org_name = keys[i]
            dest_name = keys[j]

            # get the coordinate of the origin and destionation
            origin = get_coordinate(data, org_name)
            destination = get_coordinate(data, dest_name)

            gm = googlemaps.Client(key=api_key)

            # 1. get the meta data: use imperial: miles and meters
            distance_result = googlemaps.distance_matrix.distance_matrix(
                gm, origin, destination, mode="walking", units="imperial")

            # concatonate the building names as key to save the meta data
            jdata[org_name + "|" + dest_name] = distance_result

            # 2. get the duration in seconds
            duration = distance_result['rows'][0]['elements'][0][
                'duration']['value']

            # save the data to the 2d array: bidirectional map
            array[i][j] = duration
            array[j][i] = duration

            count += 1
            print(duration)
            print(count)

    # dump the data to file
    json.dump(array.tolist(), open(get_data_path(Time_Matrix), 'w'))
    json.dump(jdata, open(get_data_path(Distance_MetaData), 'w'))

    print('success')


def get_coordinate(Building_MetaData, key):
    """
    Lookup the coordinate of each building
    :param api_key: the api key for google api
    :param Building_MetaData: the json form data of the building
    :return: [lattitude,longitutude]
    """
    lat = Building_MetaData[key][0]['geometry']['location']['lat']
    lng = Building_MetaData[key][0]['geometry']['location']['lng']
    return (lat, lng)


if __name__ == "__main__":
    api_key = 'AIzaSyAB4V8GGSxwkvmMgXXXkFx0s3cCSM0YHC0'
    Building_Names = "Building_Names.json"
    Building_MetaData = 'Building_MetaData.json'
    Building_Array = "Building_Array.json"
    Time_Matrix = "Time_Matrix.json"
    Distance_MetaData = "Distance_MetaData.json"

    load_data(api_key, Building_Names, Building_MetaData)

    create_distance_matrix(api_key, Building_MetaData,
                           Building_Array, Time_Matrix, Distance_MetaData)
