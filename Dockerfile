# File: Dockerfile
FROM rocker/tidyverse:latest

RUN apt-get -y update \
  && apt-get install -y \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
  && install2.r --error --deps TRUE \
    CARBayes \
    sf \
    sp \
    spdep
    
    sudo dnf install gdal* expat* proj*