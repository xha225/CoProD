To get data in phase1, we use PIN to instrument code locations such as loops and system calls.

**phase1Raw.data** contains the raw profiling data get from pin instrumentation. 
Since the instrumentation happens on the assembly level, there is no loop structure therefore 
we need to find a why to post-process the raw data. We store the source code location of the instrumented
assembly code, and filter out the code locations that are not loops.
**phase1Train.data** contains the training data for location-level models. 
Each sampled configuration option has its own copy of the training file.
We used Weka to learn the location-level models and outputs **phase2.data** for phase 2.
Based on the location-level model types w.r.t. weights, we calculate a ranking score for each sampled option.
In phase 3, we use ACTS for t-way covering array sampling to get **phase3Sampling.data**.
Then the framework exercises the subject to get the execution time and outputs **phase3Train.data**
