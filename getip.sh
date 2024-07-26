#!/bin/bash
ip a | grep inet | awk '{ print $2 }'
