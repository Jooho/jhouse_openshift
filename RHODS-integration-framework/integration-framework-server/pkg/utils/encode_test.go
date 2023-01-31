package utils

import (
	"bytes"
	"math/rand"
	"reflect"
	"testing"

	userpb "github.com/Jooho/integration-framework-grpc-server/pkg/api/v1/user"
	"google.golang.org/protobuf/types/known/timestamppb"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// Test converting K8S object configmap to JSON string
func TestJsonSerializer(t *testing.T) {
	//given
	k8sObjConfigMap := corev1.ConfigMap{
		TypeMeta: metav1.TypeMeta{
			Kind:       "ConfigMap",
			APIVersion: "v1",
		},
		Data: map[string]string{"foo": "bar"},
	}
	k8sObjConfigMap.Namespace = "default"
	k8sObjConfigMap.Name = "my-configmap"

	JsonBytesConfigMap := []byte{123, 34, 107, 105, 110, 100, 34, 58, 34, 67, 111, 110, 102, 105, 103, 77, 97, 112, 34, 44, 34, 97, 112, 105, 86, 101, 114, 115, 105, 111, 110, 34, 58, 34, 118, 49, 34, 44, 34, 109, 101, 116, 97, 100, 97, 116, 97, 34, 58, 123, 34, 110, 97, 109, 101, 34, 58, 34, 109, 121, 45, 99, 111, 110, 102, 105, 103, 109, 97, 112, 34, 44, 34, 110, 97, 109, 101, 115, 112, 97, 99, 101, 34, 58, 34, 100, 101, 102, 97, 117, 108, 116, 34, 44, 34, 99, 114, 101, 97, 116, 105, 111, 110, 84, 105, 109, 101, 115, 116, 97, 109, 112, 34, 58, 110, 117, 108, 108, 125, 44, 34, 100, 97, 116, 97, 34, 58, 123, 34, 102, 111, 111, 34, 58, 34, 98, 97, 114, 34, 125, 125, 10}

	//when - JsonSerialzer "K8S to JSON"
	testname := "Test converting K8S object configmap to JSON string"
	t.Run(testname, func(t *testing.T) {
		serializedJson := JsonSerializer(&k8sObjConfigMap)

		//then - serializedJson must be the same as expectedBytes
		if bytes.Compare(serializedJson, JsonBytesConfigMap) != 0 {
			t.Errorf("got %d, want %d", serializedJson, JsonBytesConfigMap)
		}
	})
}

// Test converting JSON string to K8S object configmap
func TestJsonDeserializer(t *testing.T) {
	//given
	JsonBytesConfigMap := []byte{123, 34, 107, 105, 110, 100, 34, 58, 34, 67, 111, 110, 102, 105, 103, 77, 97, 112, 34, 44, 34, 97, 112, 105, 86, 101, 114, 115, 105, 111, 110, 34, 58, 34, 118, 49, 34, 44, 34, 109, 101, 116, 97, 100, 97, 116, 97, 34, 58, 123, 34, 110, 97, 109, 101, 34, 58, 34, 109, 121, 45, 99, 111, 110, 102, 105, 103, 109, 97, 112, 34, 44, 34, 110, 97, 109, 101, 115, 112, 97, 99, 101, 34, 58, 34, 100, 101, 102, 97, 117, 108, 116, 34, 44, 34, 99, 114, 101, 97, 116, 105, 111, 110, 84, 105, 109, 101, 115, 116, 97, 109, 112, 34, 58, 110, 117, 108, 108, 125, 44, 34, 100, 97, 116, 97, 34, 58, 123, 34, 102, 111, 111, 34, 58, 34, 98, 97, 114, 34, 125, 125, 10}

	k8sObjConfigMap := corev1.ConfigMap{
		TypeMeta: metav1.TypeMeta{
			Kind:       "ConfigMap",
			APIVersion: "v1",
		},
		Data: map[string]string{"foo": "bar"},
	}
	k8sObjConfigMap.Namespace = "default"
	k8sObjConfigMap.Name = "my-configmap"

	//when - JsonSerialzer "JSON Byte to K8S Object"
	testname := "Test converting JSON string to K8S object configmap "
	t.Run(testname, func(t *testing.T) {
		deserializedjson := JsonDeserializer(JsonBytesConfigMap)

		if reflect.DeepEqual(deserializedjson, k8sObjConfigMap) {
			t.Errorf("got %v, want %v", deserializedjson, k8sObjConfigMap)
		}
	})

}
func TestConvertProtobufObj(t *testing.T) {

	userData := []*userpb.UserMessage{
		{
			UserId:      "1",
			Name:        "Henry",
			PhoneNumber: "01012341234",
			Age:         22,
			Ttt: &timestamppb.Timestamp{
				Seconds: int64(rand.Int31n(120)),
				Nanos:   rand.Int31n(120),
			},
		}, {
			UserId:      "2",
			Name:        "Simon",
			PhoneNumber: "01012341234",
			Age:         24,
			Ttt: &timestamppb.Timestamp{
				Seconds: int64(rand.Int31n(120)),
				Nanos:   rand.Int31n(120),
			},
		},
	}

	for i, user := range userData {

		jsonUser := ProtobufToJson(user)
		testname := "Convert proto message object to json and json to proto message"
		t.Run(testname, func(t *testing.T) {
			emptyUserProtobuf := &userpb.UserMessage{}
			JsonToProtobuf(jsonUser, emptyUserProtobuf)
			if emptyUserProtobuf == userData[i] {
				t.Errorf("got %v, want %v", emptyUserProtobuf, userData[i])
			}
		})
	}

}