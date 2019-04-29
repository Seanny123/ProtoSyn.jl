# -*- coding: utf-8 -*-
"""
     Created   José Pereira     April      2019
Last updated   José Pereira     April      2019
"""
from matplotlib import pyplot as plt
import numpy as np
import argparse
import re

colors = ['blue', 'darkslategrey', 'sienna', 'darkorange', 'goldenrod', 'olivedrab', 'green', 'c', 'cadetblue', 'navy', 'mediumvioletred', 'crimson', 'pink']

def main(filename):
    # Load data
    pattern = re.compile('AR:\s([0-9]+\.[0-9]+)', flags=re.S)
    with open(filename, 'r') as file_in:
        data = map(lambda ar: float(ar), pattern.findall(file_in.read()))
    average = sum(data)/float(len(data))
    
    #Plot data
    plt.plot(data, c = "sienna", label = "Acceptance Ratio")
    plt.axhline(average, linewidth = 1, alpha = .3, label = "Average: %f" % (average))
    plt.title("Run Log")
    plt.xlabel("# Structure")
    plt.ylabel("Acceptance Ratio")
    plt.legend(loc = 4)
    plt.show()


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Plot energy contributions from ProtoSyn run')
    parser.add_argument('-f', '--file', type=str, help='Input file to be plotted', required = True)
    args = parser.parse_args()

    main(args.file)
