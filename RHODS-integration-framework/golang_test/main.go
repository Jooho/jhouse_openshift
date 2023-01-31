package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	// "os"
)

func main() {
	var crData []map[string]interface{}
	var ifData []map[string][]map[string]interface{}

	cr, err := ioutil.ReadFile("./cr.json")
	// fmt.Println(b)
	if err != nil {
		fmt.Println(err)
		return
	}
	integration, err := ioutil.ReadFile("./if.json")
	// fmt.Println(b)
	if err != nil {
		fmt.Println(err)
		return
	}

	json.Unmarshal(cr, &crData)
	json.Unmarshal(integration, &ifData)

	// fmt.Println(crData)
	((ifData[0])["applications"])[0]["example"] = crData
	fmt.Println(ifData)
	
	ifmarshal,_ := json.MarshalIndent(ifData,"", " ")
	fmt.Printf("%s",string(ifmarshal))

	err = ioutil.WriteFile("./integration-openvino.json", ifmarshal, os.FileMode(0644))
	if err != nil{
		fmt.Println(err)
		return
	}
}
