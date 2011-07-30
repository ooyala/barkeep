#!/bin/sh

sequel -m migrations/ "sqlite://dev.db"
