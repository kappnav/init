/*****************************************************************
 *
 * Copyright 2019 IBM Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

 * http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 *****************************************************************/

// input is output from: kubectl get configmap webconsole-config -n openshift-web-console -o json
// output is content of data['webconsole-config.yaml']

const yaml = require('js-yaml');
const getStdin = require('get-stdin');

(async () => {
    var stdin= await getStdin(); 
	var json= JSON.parse(stdin); 
	cfg= json.data['console-config.yaml'];

	// Get config or throw exception on error
	try {
		  var config = yaml.safeLoad(cfg,"JSON_SCHEMA");
		  var consoleURL = config.clusterInfo.consoleBaseAddress;
		  var lastChar = consoleURL.substr(-1);
		  if (lastChar == '/') {
			 // trim off the trailing '/'
			 consoleURL = consoleURL.substr(0, consoleURL.length-1);
		  }
		  console.log(consoleURL); 
	} catch (e) {
  		console.log(e);
  		process.exit(1); 
	}
})();