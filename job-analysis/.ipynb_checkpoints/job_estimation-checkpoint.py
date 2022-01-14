#!/usr/bin/env python
# -*- coding: utf-8 -*-
import numpy as np
import pandas as pd
from matplotlib import pyplot as plt
from scipy.optimize import curve_fit


def fit_func_poly(x, *coeffs):
    return np.polyval(coeffs, x)


def fit_func_power(x, *coeffs):
    # fit function of the form f(x) = a*x**b + c
    return coeffs[0]*x**coeffs[1] + coeffs[2]


def hms_to_sec(timestr):
    h, m, s = [float(i) for i in timestr.split(":")]
    return int(h * 3600 + m * 60 + s)


def get_func_form(fit_func):
    return fit_func.__name__.split('_')[-1]


def fit_and_label(fit_func, x, y, num_params):
    popt, _ = curve_fit(fit_func, x, y, np.ones(num_params))
    func_form = get_func_form(fit_func)
    label = f'{func_form}: '
    if func_form == 'poly':
        label += ''.join([f'{c:.2e} x^{len(popt) - i - 1} + '
                         for (i, c) in enumerate(popt)])
        label = label[:-6]
    if func_form == 'power':
        label += f'{popt[0]:.2e} x^{popt[1]:.2e} + {popt[2]:.2e}'
    return popt, label


def fit_and_plot(fit_func, x, y, max_x, target_value, num_params=1,
                 title=None):

    popt, label = fit_and_label(fit_func, x, y, num_params)

    # plotting
    plt.scatter(x, y)
    x_line = np.arange(min(x), max_x, 1)
    y_line = fit_func(x_line, *popt)
    plt.plot(x_line, y_line, "--", color="red", label=label)
    plt.legend(loc='lower right')
    plt.title(title)
    plt.gca().annotate(
        f"{int(target_value/1000)}k rows needs ~{y_line[target_value]:.2f}",
        xy=(target_value, y_line[target_value]),
        xytext=(2, y_line[target_value]),
        arrowprops=dict(arrowstyle="->",
                        connectionstyle="angle3,angleA=0,angleB=90")
    )
    plt.tight_layout()
    plt.savefig(title)
    plt.show()

if __name__ == "__main__":
    jobres_df = pd.read_csv("job-resource-stats.csv")
    jobres_df['time'] = jobres_df['time'].apply(hms_to_sec)

    # power for memory
    plot_title = 'memory-power-fit'
    fit_and_plot(fit_func_power, jobres_df["input_size"], jobres_df["memory"],
             210000, 200000, num_params=3, title=plot_title)

    # # power for time
    # plot_title = 'time-power-fit'
    # fit_and_plot(fit_func_power, list(jobres_df["input_size"])[:-2],
    #              list(jobres_df["time"])[:-2], 210000, 200000,
    #              num_params=3, title=plot_title)
    #
    # # quadratic for memory
    # plot_title = 'memory-deg2-fit'
    # fit_and_plot(fit_func_poly, jobres_df["input_size"], jobres_df["memory"],
    #              210000, 200000, num_params=3, title=plot_title)
    #
    #
    # # quadratic for time
    # plot_title = 'time-deg2-fit'
    # fit_and_plot(fit_func_poly, list(jobres_df["input_size"])[:-2],
    #              list(jobres_df["time"])[:-2], 210000, 200000,
    #              num_params=3, title=plot_title)
