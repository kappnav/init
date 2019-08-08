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

// add key: value to config map data
// stdin-json - config map JSON
// parameters - key, value

var myArgs = process.argv.slice(2);

var key = myArgs[0];
var value = myArgs[1];

const yaml = require('js-yaml');
const getStdin = require('get-stdin');

(async () => {
    	var stdin= await getStdin(); 

	// Get config or throw exception on error
	try {
  		var config = yaml.safeLoad(stdin,"JSON_SCHEMA");
		config.data[key]= value;
		var json= JSON.stringify(config);
  		console.log(json); 
	} catch (e) {
  		console.log(e);
  		process.exit(1); 
	}
})();