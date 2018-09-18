import java.io.File;
import java.io.FileOutputStream;
import java.io.PrintWriter;
import java.util.Random;

import weka.classifiers.Classifier;
import weka.classifiers.Evaluation;
import weka.classifiers.functions.SMOreg;
import weka.core.Instances;
import weka.core.Utils;
import weka.core.converters.ConverterUtils.DataSource;


public class PredictionModel {
	private static int CS_FOLD = 10;
	/*
	 * args[0]: path to data training file
	 */
	public static void main(String[] args) throws Exception {
		if (args.length != 1) {
			System.out.println("Usage: app trainingDatapath");
		} else {
			DataSource source = new DataSource(args[0]);
			Instances instances = source.getDataSet();
			instances.setClassIndex(instances.numAttributes() - 1);
			// System.out.println(instances.toString());
			Classifier smoReg2 = new SMOreg();
			
			smoReg2.setOptions(Utils
					.splitOptions("-C 1.0 -N 0 -K \"weka.classifiers.functions.supportVector.PolyKernel -C 250007 -E 2.0\""));
			for (String op : smoReg2.getOptions()) {
				System.out.println(op);
			}
	
			smoReg2.buildClassifier(instances);
			System.out.println(smoReg2.toString());
			Evaluation eval = new Evaluation(instances);
			eval.crossValidateModel(smoReg2, instances, CS_FOLD, new Random());
			System.out.println(eval.toSummaryString());
			
			PrintWriter writer = new PrintWriter(new FileOutputStream(
					new File("relAbsErr.out"), true));
			writer.println(eval.relativeAbsoluteError());
			writer.close();
			
			//System.out.println (Evaluation.evaluateModel(smoReg2, Utils.splitOptions("-t " + args[0] + "--split-percentage 66")));
			//System.out.println(eval.errorRate());
			
			

		} // if
	} // main
}
