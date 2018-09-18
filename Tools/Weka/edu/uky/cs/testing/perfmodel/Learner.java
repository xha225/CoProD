package edu.uky.cs.testing.perfmodel;

import weka.classifiers.Classifier;

public class Learner {
	// Linear Regression
	public static final String LR = "LR";
	// Support Vector Machine Regression
	public static final String SMO = "SMO";
	public static final String SMO2 = "SMO2";
	// Multi-Perceptron
	public static final String MP = "MP";
	// Constant
	public static final String CONST = "CONST";
	private String name;
	private String[] cmdOptions;
	private double weight;
	private Classifier learner;

	public Learner(Classifier c, String classifierName, String[] ops) {
		learner = c;
		name = classifierName;
		cmdOptions = ops;
		try {
			Init();
		} catch (Exception e) {
			e.printStackTrace();
		}
	} // Learner

	public void Init() throws Exception {
		if (cmdOptions != null) {
			learner.setOptions(cmdOptions);
		}
	}

	public void SetName(String name) {
		this.name = name;
	}

	public String GetName() {
		return name;
	}

	public void SetCmdOptions(String[] ops) {
		cmdOptions = ops;
	}

	public String[] GetCmdOptions() {
		return cmdOptions;
	}

	public void setLearner(Classifier l) {
		learner = l;
	}

	public Classifier getLearner() {
		return learner;
	}

} // class Learner
