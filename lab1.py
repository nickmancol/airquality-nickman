import os
import pandas as pd
import numpy as np
#from sklearn.svm


def merge_data(folder='./', preffix='mi_pollution'):
    # Joins all the preffix*.csv files and the data from stations of the preffix_legend-mi.csv
    if not os.path.exists(folder):
        print(f"folder {folder} doesn't exist's, no data merged")
        return

    dataframes = []
    df_names = pd.DataFrame()
    for filename in os.listdir(folder):
        if filename.startswith(preffix) and filename.endswith(".csv"):
            dataframes.append(pd.read_csv(folder+filename))

        if 'legend' in filename and filename.endswith(".csv"):
            df_names = pd.read_csv(folder+filename)

    df_total = pd.DataFrame()
    for df in dataframes:
        df_total = df_total + df
    #TODO: merge with legend and plot
    print(np.shape(df))


if __name__ != "main":
    merge_data('/home/nickman/code/MADAS/II/Lab Rossi/MI_Air_Quality/data/')
