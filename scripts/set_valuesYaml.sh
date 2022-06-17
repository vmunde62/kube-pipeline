if [ $clusterName = cluster1 ]; then
    valuesYaml='c1values.yaml'
elif [ $clusterName = cluster2 ]; then
    valuesYaml='c2values.yaml'
elif [ $clusterName = cluster3 ]; then
    valuesYaml='c3values.yaml'
fi

echo $valuesYaml