## WEKA
1. Put Weka.jar in $PATH (I think it does not matter, a classpath for java should be set instead)
2. Run java -cp weka.jar weka.classifiers.trees.J48 -t data/weather.numeric.arff -i
3. Convert CSV (with header) to arff using the converter class
java -cp weka.jar weka.core.converters.CSVLoader yourCsvDataFile > yourConverted.arff
To start Weka UI: java -cp weka.jar weka.gui.GUIChooser
4. How to load and evaluate data on a saved model?
Right click load model in the "Result list", load test data from "Supplied test set", then, right click
on the model and select "Re-evaluate model on current test"


## WEKA machine learning code

1. javac -cp ./weka.jar *.java edu/uky/cs/testing/perfmodel/*.java

------------Script Usage-------------
1. Each project should have a separate copy of the data processing script
2. There are three major scripts, for example, in the Apache project, you will use
* apacheGo.sh to get the single option ranking
* apachePairWiseDriver.sh to get the configuration interaction ranking
* buildPerfModel.sh to get the final performance prediction model
