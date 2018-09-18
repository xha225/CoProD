import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map.Entry;
import java.util.Random;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FilenameFilter;
import java.io.PrintWriter;

import edu.uky.cs.testing.perfmodel.Feature;
import edu.uky.cs.testing.perfmodel.FeatureMask;
import edu.uky.cs.testing.perfmodel.Learner;
import weka.classifiers.Classifier;
import weka.classifiers.Evaluation;
import weka.classifiers.functions.LinearRegression;
import weka.classifiers.functions.MultilayerPerceptron;
import weka.classifiers.functions.SMOreg;
import weka.clusterers.SimpleKMeans;
import weka.core.Instances;
import weka.core.Utils;
import weka.core.converters.ConverterUtils.DataSource;
import weka.filters.Filter;
import weka.filters.unsupervised.attribute.Remove;

public class FeatureModeling {
	private static String CONFIG_DATA_DIR;
	// Setup cross validation fold
	private static int CS_FOLD = 2;
	// Setup minimum number of instances in the training set
	private static int MIN_INS = 3;
	private static int WeightOption = 1;

	private static int CONST_WEIGHT = 1;
	private static int LINEAR_WEIGHT = 2;
	private static int QUAD_WEIGHT = 3;
	private static int WEIGHT_UPPER_BOUND = 5;

	private static String featureDir;
	private static String featureFilter;
	private static FeatureMask perfMetricMask = new FeatureMask();
	private static FeatureMask sysCallMask = new FeatureMask();
	private static HashMap<String, Learner> classifiers = new HashMap<String, Learner>();
	private static String confInterName;
	private static HashMap<String, Float> featureCosts = new HashMap<String, Float>();
	private static HashMap<String, Double> featureErrRate = new HashMap<String, Double>();
	private static HashMap<String, Integer> featureTrainInstance = new HashMap<String, Integer>();
	private static ArrayList<Integer> maskInd = new ArrayList<Integer>();

	// Select machine learning method to use

	public static String GetSelectedModel(String featureName, String dir,
			FeatureMask mask) throws Exception {
		Feature f = new Feature();
		System.err.println("\nFile: " + featureName);
		// Read all the instances in the file (ARFF, CSV, XRFF, ...)
		// Read DATA file
		DataSource source = new DataSource(dir + "/" + featureName);
		Instances instances = source.getDataSet();
		// TODO: add instance count
		featureTrainInstance.put(featureName, instances.numInstances());
		// Check the size of training file
		if (instances.numInstances() < FeatureModeling.MIN_INS)
			return "TooFewTrainingData";
		// Set attribute to be the class
		instances.setClassIndex(mask.GetClassColumn());
		// Print attribute name
		// instances.attribute(0).name());
		// Print attribute value
		// writer.print(instances.firstInstance().stringValue(0));
		// Print header and instances.
		// System.out.println(instances);

		// Data filtering, get rid of unrelated features such as file location
		Remove rm = new Remove();
		rm.setAttributeIndicesArray(mask.GetColumnsToBeRemoved());
		rm.setInputFormat(instances);
		Instances filteredInstance = Filter.useFilter(instances, rm);

		filteredInstance.setClassIndex(mask.GetClassColumn());

		for (String learnMethod : classifiers.keySet()) {
			Classifier c = classifiers.get(learnMethod).getLearner();

			try {
				// Build classifier
				c.buildClassifier(filteredInstance);
				System.err.println(learnMethod + ":" + c.toString());
				// Add model to collection
				f.AddModels(learnMethod, c);
				// Evaluation
				Evaluation eval = new Evaluation(filteredInstance);
				eval.crossValidateModel(c, filteredInstance, CS_FOLD, new Random());
				System.err.println(learnMethod + ":" + eval.errorRate());
				/*
				 * use this code to evaluate where more training data is needed.
				 * calculate the error, and provide a ranked list of configuration
				 * option value double[] prediction = eval.evaluateModel(c,
				 * filteredInstance); for (int i = 0; i <
				 * filteredInstance.numInstances(); i++) {
				 * System.err.println("@@ actual: "
				 * +filteredInstance.instance(i).classValue
				 * ()+" prediction"+prediction[i]); }
				 */
				// Based on RMS error, determine if another learning method is needed.
				// Add evaluation to collection
				f.AddEvalItem(learnMethod, eval);
			} catch (Exception e) {
				System.err.println("Failed to build:" + learnMethod);
				e.printStackTrace();
			}
		}

		// System.out.println("Test linear regression model: " +
		// f.GetModel(Feature.LR).toString())

		String rtn = f.GetSelectedModel();

		featureErrRate.put(featureName, f.GetModelErrRate());
		System.err.println(featureName + ":" + f.GetModelErrRate());
		return rtn;
	} // GetSelctedModel

	public static HashMap<String, String> generateFeatureModels(
			String featurePath, FeatureMask mask) throws Exception {
		// Key: loopId; Value:model
		HashMap<String, String> featureModels = new HashMap<String, String>();
		// HashMap<String,Float> featureCosts=new HashMap<String,Float>();

		FilenameFilter fileNameFilter = new FilenameFilter() {
			@Override
			public boolean accept(File dir, String name) {
				for (String ff : featureFilter.split(",")) {
					if (name.equals(ff))
						return true;
				}
				return false;
			}
		};

		File[] files;
		if (featureFilter.equals("")) { // Don't apply filter
			files = new File(featurePath).listFiles();
		} else {
			files = new File(featurePath).listFiles(fileNameFilter);
		}
		// Use the ARFF file name for the feature model file
		try {
			for (File file : files) {
				if (file.isDirectory()) {
					continue;
				} else {
					featureModels.put(file.getName(),
							GetSelectedModel(file.getName(), featurePath, mask));
				}
			} // for
		} catch (Exception e) {
			e.printStackTrace();
		}

		return featureModels;
	} // GenerateFeatureModelFile

	public static LinkedHashMap<String, Float> getPerfRank(
			HashMap<String, Float> configs) {

		List<Entry<String, Float>> list = new LinkedList<Entry<String, Float>>(
				configs.entrySet());

		Collections.sort(list, new Comparator<Entry<String, Float>>() {
			public int compare(Entry<String, Float> c1, Entry<String, Float> c2) {
				return c2.getValue().compareTo(c1.getValue());
			}
		});

		// LinkedHashMap is used to maintain the order when iterating through
		// entries
		LinkedHashMap<String, Float> hmSortedConfig = new LinkedHashMap<String, Float>();
		for (Entry<String, Float> entry : list) {
			hmSortedConfig.put(entry.getKey(), entry.getValue());
			// System.out.println("entry:" +entry.getValue());
		}

		return hmSortedConfig;
	}

	// Calculate performance cost based on each model associated with the feature
	// weightMethod: 1: absolute; 2: weighted sum
	public static HashMap<String, Float> calculatePerfCost(
			HashMap<String, HashMap<String, String>> featureModels, int weightMethod) {
		HashMap<String, Float> configScores = new HashMap<String, Float>();
		try {
			// Open file in appending mode
			PrintWriter confModWriter = new PrintWriter(new FileOutputStream(
					new File("confModel.out"), true));

			for (String confName : featureModels.keySet()) {
				confModWriter.println("ConfName:" + confName);
				HashMap<String, String> fMods = featureModels.get(confName);
				for (String loopId : fMods.keySet()) {
					confModWriter.println("-" + loopId + ":" + fMods.get(loopId) + "("
							+ featureTrainInstance.get(loopId) + ")" + ","
							+ featureErrRate.get(loopId));
				}
			}
			confModWriter.close();
		} catch (FileNotFoundException e) {
			e.printStackTrace();
		}
		
		// Reset weights
		ResetWeights();
		// Define the weight schemes
		String[] Weights = {"1-2-3","1-2-4","1-10-100"};
		for(String weight:Weights){
					for (String confName : featureModels.keySet()) {
						UpdateWeights(weight);
						String weightedConfName = GetWeightedName(confName);
						float score = 0;
						switch (weightMethod) {
						case 1:
							score = GetAbsSum(featureModels.get(confName));
							break;
						case 2:
							score = GetWeightedSum(featureModels.get(confName));
							break;
						} // switch
						configScores.put(weightedConfName, score);
					}// confName
		}// for
		return configScores;
	} // calculatePerfCost

	private static float GetAbsSum(HashMap<String, String> models) {
		float score = 0;

		for (String loopId : models.keySet()) {
			String model = models.get(loopId);
			float loopCost = featureCosts.get(loopId);
			switch (model) {
			case Learner.CONST:
				score += CONST_WEIGHT * loopCost;
				break;
			case Learner.LR:
			case Learner.SMO:
				score += LINEAR_WEIGHT * loopCost;
				break;
			case Learner.SMO2:
			case Feature.MP:
				score += QUAD_WEIGHT * loopCost;
				break;
			default:
				break;
			} // switch
		} // for, loop through models

		return score;
	} // GetAbsSum

	private static String GetWeightedName(String confName) {
		return confName + "," + CONST_WEIGHT + "-" + LINEAR_WEIGHT + "-"
				+ QUAD_WEIGHT;
	} // GetWeightedName

	private static void ResetWeights() {
		CONST_WEIGHT = 1;
		LINEAR_WEIGHT = 2;
		QUAD_WEIGHT = 3;
	} // ResetWeights

	private static int GetTotalWeight() {
		return CONST_WEIGHT + LINEAR_WEIGHT + QUAD_WEIGHT;
	} // GetTotalWeight

	private static void UpdateWeights(String weight) {
		String[] vals=weight.split("-");
		CONST_WEIGHT = Integer.parseInt(vals[0]);
		LINEAR_WEIGHT = Integer.parseInt(vals[1]);
		QUAD_WEIGHT = Integer.parseInt(vals[2]);;
	} // UpdateWeights

	private static float GetWeightedSum(HashMap<String, String> models) {
		// TODO: define weights
		float totalWeight = GetTotalWeight();
		// for, loop through models

		float score = 0;
		for (String loopId : models.keySet()) {
			String model = models.get(loopId);
			float loopCost = featureCosts.get(loopId);
			switch (model) {
			case Learner.CONST:
				score += CONST_WEIGHT / totalWeight * loopCost;
				break;
			case Learner.LR:
			case Learner.SMO:
				score += LINEAR_WEIGHT / totalWeight * loopCost;
				break;
			case Learner.SMO2:
			case Feature.MP:
				score += QUAD_WEIGHT / totalWeight * loopCost;
				break;
			default:
				break;
			} // switch
		} // for, loop through models
		return score;
	} // GetWeightedSum

	private static void InitLearners() {
		Classifier linearReg = new LinearRegression();
		Learner lr;
		try {
			lr = new Learner(linearReg, Learner.LR, Utils.splitOptions("-S 1 -C"));
			classifiers.put(Learner.LR, lr);
		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		// SVM regression with linear kernel
		Classifier smoReg = new SMOreg();
		Learner smo;
		try {
			// -E is the option for specify the exponent (highest order) of the
			// PolyKernel
			smo = new Learner(
					smoReg,
					Learner.SMO,
					Utils
							.splitOptions("-K \"weka.classifiers.functions.supportVector.PolyKernel -C 250007 -E 1.0\""));
			classifiers.put(Learner.SMO, smo);
		} catch (Exception e) {
			e.printStackTrace();
		}

		// Use the second-order polynomial kernel
		Classifier smoReg2 = new SMOreg();
		Learner smo2;
		try {
			smo2 = new Learner(
					smoReg2,
					Learner.SMO2,
					Utils
							.splitOptions("-K \"weka.classifiers.functions.supportVector.PolyKernel -C 250007 -E 2.0\""));
			classifiers.put(Learner.SMO2, smo2);

			/*
			 * Ref:
			 * http://weka.8497.n7.nabble.com/SMOreg-with-Polykernal-Result-Interpretation
			 * -td27851.html SMOreg
			 * 
			 * Support vectors: -0.08275846744395952 * k[1] -0.07041146459438122 *
			 * k[3] -0.043556617385718525 * k[4] +1.0 * k[5] -0.10093770756096017 *
			 * k[6] +0.29766425698501925 * k[7] -1.0 * k[8] + 0.0018 In the
			 * output,k[i] stands for K(x(i),x), where K(,) is the kernel function,
			 * x(i) is the training instance at location i-1, and x is the instance
			 * you want to get a prediction for. Let's say we are looking at x(1),
			 * and, for simplicity, assume that it has only two attribute values, for
			 * attributes product1 and product2. Let's say they are 7 and 3 for x(1).
			 * 
			 * With a poly kernel with exponent 2 (assuming no lower-order terms), and
			 * based on the output you gave, the first term in the sum used for making
			 * a prediction would be:
			 * 
			 * -0.08275846744395952 * [7 * product1 + 3 * product2]^2
			 */
		} catch (Exception e) {
			e.printStackTrace();
		}

		// Neural Network
		Classifier multiPerceptron = new MultilayerPerceptron();
		Learner mp;
		try {
			mp = new Learner(multiPerceptron, Learner.MP, null);
			classifiers.put(Learner.MP, mp);
		} catch (Exception e) {
			e.printStackTrace();
		}
	} // InitLearners

	public static String GetInstanceInCluster(int clusterInd, int[] assignments) {
		int i = 0;
		for (int clusterNum : assignments) {
			if (clusterNum == clusterInd) {
				System.out.printf("Instance %d -> Cluster %d \n", i, clusterNum);
			}
			i++;
		}
		return "nothing";
	}

	// Clustering
	public static void GetCluster() throws Exception {
		// http://www.programcreek.com/2014/02/k-means-clustering-in-java/
		SimpleKMeans kmeans = new SimpleKMeans();
		// seed is used to determine the center of the cluster
		kmeans.setSeed(10);
		kmeans.setPreserveInstancesOrder(true);
		kmeans.setNumClusters(2);
		DataSource clusterData = new DataSource(
				"/home/x/PlayGround/weka-3-6-14/data/s4.cluster.filtered.arff");
		// BufferedReader clusterData = new BufferedReader(new
		// FileReader("/home/x/PlayGround/weka-3-6-14/data/cluster.csv"));
		Instances clusterInstances = clusterData.getDataSet();

		// String[] options = new String[2];
		// options[0] = "-R"; // -R <index1,index2-index4,...>
		// options[1] =
		// "1,2,3,5,7,8,9,10,11,13,14,19,21,23,24,25,27,28,29,30,31,32,35,36,37,40,43,45,46,47,48,49,59,60,61,65,69,71,72,74,75,76,77,78,80,81,82,83,87,90,91,92,95,96,98,99,100,101,105,106,107,116,120,121,122,123,127,128,129,130,132,133,134,138,140,143,144,145,148,150,152,154,155,158,161,163,164,165";
		// // first attribute
		Remove remove = new Remove();
		// remove.setOptions(options);
		remove.setInputFormat(clusterInstances); // inform filter about dataset
																						 // **AFTER** setting options
		Instances filteredClusterInstances = Filter.useFilter(clusterInstances,
				remove); // apply filter

		kmeans.buildClusterer(filteredClusterInstances);
		// This array returns the cluster number (starting with 0) for each instance
		// The array has as many elements as the number of instances
		int[] assignments = kmeans.getAssignments();

		int i = 0;
		for (int clusterNum : assignments) {
			System.out.printf("Instance %d -> Cluster %d \n", i, clusterNum);
			i++;
		}

		for (int clusterInd = 0; clusterInd < kmeans.getNumClusters(); clusterInd++) {
			System.out.printf("Print instances in cluster %d\n", clusterInd);
			GetInstanceInCluster(clusterInd, assignments);
		}

		i = 0;
		int[] clusterSizes = kmeans.getClusterSizes();
		for (int cSize : clusterSizes) {
			System.out.printf("Cluster %d, size: %d\n", i, cSize);
			i++;
		}

		System.out.printf("Squared error: %f\n", kmeans.getSquaredError());
	} // GetCluster

	public static void GetOpRankScore(String configPath) throws Exception {
		// Setup mask for loop count data
		perfMetricMask.SetClassColumn(1);

		// int[] colToRemoveLoopCount = { 0, 1, 3, 4, 5, 6, 8, 9 };
		// int[] colToRemoveLoopIns = { 0, 1, 3, 5, 6, 7, 8, 9 };

		perfMetricMask.SetColumnsToBeRemoved(ToIntArray(maskInd
				.toArray(new Integer[maskInd.size()])));

		sysCallMask.SetClassColumn(0);
		int[] scColToRemove = { 0, 1 };
		sysCallMask.SetColumnsToBeRemoved(scColToRemove);

		InitLearners();
		// One configuration option per HashMap
		// Key: FeatureName; Value:ModelName
		HashMap<String, HashMap<String, String>> configModels = new HashMap<String, HashMap<String, String>>();

		// TODO: incorporate the test case folder
		// S4_INTER_T_DATA/c0-1/c1/
		try {
			// TODO: report when path does not work, it throws exceptions now.
			// Also this should be moved to a global configuration file
			configModels.put(confInterName,
					generateFeatureModels(featureDir, perfMetricMask));
		} catch (Exception e) {
			e.printStackTrace();
		}

		// Calculate performance cost
		// TODO: how to indicate the measure to use when doing ranking?
		HashMap<String, Float> alConfigs = calculatePerfCost(configModels,
				WeightOption);
		for (String confName : alConfigs.keySet()) {
			// Print performance cost
			System.out.println(confName + "," + alConfigs.get(confName));
		}
	} // GetOpRankScore

	public static int[] ToIntArray(Integer[] input) {
		int[] rtn = new int[input.length];
		for (int i = 0; i < input.length; i++) {
			rtn[i] = input[i].intValue();
		}
		return rtn;
	} // ToIntArray

	public static void GetSingleOpRanking() throws Exception {
		// Setup mask for loop count data
		perfMetricMask.SetClassColumn(1);
		perfMetricMask.SetColumnsToBeRemoved(ToIntArray(maskInd
				.toArray(new Integer[maskInd.size()])));

		sysCallMask.SetClassColumn(0);
		int[] scColToRemove = { 0, 1 };
		sysCallMask.SetColumnsToBeRemoved(scColToRemove);

		InitLearners();

		// Key: configuration name; Value: performance score
		HashMap<String, Float> alConfigs;
		LinkedHashMap<String, Float> alSortedConfigs;

		// One configuration option per HashMap
		// Key: FeatureName; Value:ModelName
		HashMap<String, HashMap<String, String>> configModels = new HashMap<String, HashMap<String, String>>();
		// HashMap<String, HashMap<String, String>> configSysCallModels = new
		// HashMap<String, HashMap<String, String>>();
		// Loop through the ARFF file folder
		File[] files = new File(CONFIG_DATA_DIR).listFiles();
		// Use the ARFF file name for the feature model file
		// TODO: incorporate the test case folder
		try {
			for (File configDir : files) {
				if (configDir.isDirectory()) {
					// Configuration directory
					String configName = configDir.getName();

					// configSysCallModels.put(configName,
					// generateFeatureModels(configPath, "/SysLD/1/", sysCallMask));
					// TODO: report when path does not work, it throws exceptions now.
					// Also this should be moved to a global configuration file
					configModels.put(configName,
							generateFeatureModels(featureDir, perfMetricMask));
				} else {
					// In case of a file continue;
				}
			}// for
		} catch (Exception e) {
			e.printStackTrace();
		}

		// Calculate performance cost
		// TODO: how to indicate the measure to use when doing ranking?
		alConfigs = calculatePerfCost(configModels, WeightOption);
		// alConfigs = calculatePerfCost(configSysCallModels);
		// Output rank
		alSortedConfigs = getPerfRank(alConfigs);

		for (String confName : alSortedConfigs.keySet()) {
			// Print performance cost
			System.out.println(confName + "," + alSortedConfigs.get(confName));
		}
	} // GetSingleOpRanking

	/*
	 * Version 0.4b args[0]: loop ids; args[1]: path; args[2]: mode; args[3]:
	 * learning data path; args[4]: loop cost; args[5]: training data columns, it
	 * is normally the configuration option value and a selected performance
	 * measure; args[6]: weight option, default to 1: absolute weight Interaction
	 * evaluation arguments // "0x40141e.csv" //
	 * "/home/x/PlayGround/pin-2.14-71313-gcc.4.4.7-linux/source/tools/ManualExamples/S4_CONFIG_INTER/c2/c0-1/"
	 * // 1 1 Single option evaluation arguments ""
	 * "/home/x/PlayGround/pin-2.14-71313-gcc.4.4.7-linux/source/tools/ManualExamples/Apache_CONFIG_DATA/"
	 * 0 1s s
	 */
	public static void main(String[] args) throws Exception {
		if (args.length != 8) {
			System.out
					.print("Usage: java FeatureModeling loopIds ConfigDtaPath mode TrainDataPath loopCosts TrainDataCols WeightMethod MaskLength");
		} else {
			for (String arg : args) {
				System.err.println(arg);
			}

			featureFilter = args[0];
			CONFIG_DATA_DIR = args[1];
			System.err.println("CONFIG_DATA_DIR:" + CONFIG_DATA_DIR);
			String mode = args[2];

			// Weight method
			if (!"".equals(args[6])) {
				WeightOption = Integer.parseInt(args[6]);
			}

			int maskLength = 10;
			if (!args[7].isEmpty()) {
				maskLength = Integer.parseInt(args[7]);
			}
			for (int i = 0; i < maskLength; i++) {
				maskInd.add(i);
			}

			// TODO: Calculate the header lenth automatically
			for (String ind : args[5].split(",")) {
				maskInd.remove(new Integer(ind));
			}
			System.err.println("Columns of training data to be removed:" + maskInd);

			if (args[3].isEmpty()) {
				throw new Exception("Missing training data folder");
			} else {
				featureDir = args[3];
			}

			String[] loopIds = args[0].split(",");
			String[] loopCosts = args[4].split(",");
			for (int i = 0; i < loopIds.length; i++) {

				featureCosts.put(loopIds[i], Float.parseFloat(loopCosts[i]));
			}
			System.err.println(featureCosts.toString());

			String[] folderNames = CONFIG_DATA_DIR.split("/");
			int len = folderNames.length;
			// featureCosts.put()
			switch (mode) {
			case "0":
				GetSingleOpRanking();
				break;
			case "1": // For pair-wise options
				confInterName = folderNames[len - 2] + "-" + folderNames[len - 1];
				GetOpRankScore(CONFIG_DATA_DIR);
				break;
			case "2": // For single option
				confInterName = folderNames[len - 1];
				System.err.println("confInterName:" + confInterName);
				GetOpRankScore(CONFIG_DATA_DIR);
				break;
			} // switch

			// GetCluster();
		}
	} // main

} // FeatureModeling

