package utils

import (
	"log"

	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
	"k8s.io/apimachinery/pkg/runtime"
	k8sJson "k8s.io/apimachinery/pkg/runtime/serializer/json"
	"k8s.io/client-go/kubernetes/scheme"
)

func ProtobufToJson(pb proto.Message) string {
	marshaler := protojson.MarshalOptions{
		Indent:          "  ",
		UseProtoNames:   true,
		EmitUnpopulated: true,
		Multiline: true,
	}
	j, err := marshaler.Marshal(pb)
	if err != nil {
		log.Println("Can't convert Protobuf to JSON", err)
	}
	// the return []byte type to string
	return string(j)
}

func JsonToProtobuf(json string, pb proto.Message) {
	// Unmarshal accept []byte, converting json string to []byte
	err := protojson.Unmarshal([]byte(json), pb)
	if err != nil {
		log.Println("Can't convert from JSON to Protobuf", err)
	}
}

// K8s Typed Object to JSON 
func JsonSerializer(obj runtime.Object) []byte {

	encoder := k8sJson.NewSerializerWithOptions(
		k8sJson.DefaultMetaFactory, // jsonserializer.MetaFactory
		scheme.Scheme,              // runtime.ObjectCreater
		scheme.Scheme,              // runtime.ObjectTyper
		k8sJson.SerializerOptions{
			Yaml:   false,
			Pretty: false,
			Strict: false,
		},
	)
	encoded, err := runtime.Encode(encoder, obj)
	if err != nil {
		panic(err.Error())
	}
	return encoded
}

// JSON To K8s Typed Object
func JsonDeserializer(obj []byte) runtime.Object {

	decoder := k8sJson.NewSerializerWithOptions(
		k8sJson.DefaultMetaFactory, // jsonserializer.MetaFactory
		scheme.Scheme,              // runtime.Scheme implements runtime.ObjectCreater
		scheme.Scheme,              // runtime.Scheme implements runtime.ObjectTyper
		k8sJson.SerializerOptions{
			Yaml:   false,
			Pretty: false,
			Strict: false,
		},
	)

	// The actual decoding is much like stdlib encoding/json.Unmarshal but with some
	// minor tweaks - see https://github.com/kubernetes-sigs/json for more.
	decoded, err := runtime.Decode(decoder, obj)
	if err != nil {
		panic(err.Error())
	}
	return decoded
}
