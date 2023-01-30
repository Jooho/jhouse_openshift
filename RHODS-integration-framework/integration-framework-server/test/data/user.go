package data

import (
	"math/rand"
	// "time"

	userpb "github.com/Jooho/integration-framework-grpc-server/pkg/api/v1/user"
	// "google.golang.org/protobuf/types/known/structpb"
	"google.golang.org/protobuf/types/known/timestamppb"
	// v1 "k8s.io/api/core/v1"
	// v1 "k8s.io/apimachinery/pkg/runtime";
)

// var UserData = []*userpb.UserMessage{
// 	{
// 		UserId: "1",
// 		Name: "Henry",
// 		PhoneNumber: "01012341234",
// 		Age: 22,
// 		Configmap: &v1.ConfigMap{},
// 	},
// 	{
// 		UserId: "2",
// 		Name: "Michael",
// 		PhoneNumber: "01098128734",
// 		Age: 55,
// 		Configmap: &v1.ConfigMap{},
// 	},
// 	{
// 		UserId: "3",
// 		Name: "Jessie",
// 		PhoneNumber: "01056785678",
// 		Age: 15,
// 		Configmap: &v1.ConfigMap{},
// 	},
// 	{
// 		UserId: "4",
// 		Name: "Max",
// 		PhoneNumber: "01099999999",
// 		Age: 37,
// 		Configmap: &v1.ConfigMap{},
// 	},
// 	{
// 		UserId: "5",
// 		Name: "Tony",
// 		PhoneNumber: "01012344321",
// 		Age: 25,
// 		Configmap: &v1.ConfigMap{},
// 	},
// }



var UserData = []*userpb.UserMessage{
	{
		UserId: "1",
		Name: "Henry",
		PhoneNumber: "01012341234",
		Age: 22,
		Ttt: &timestamppb.Timestamp{
			Seconds: int64(rand.Int31n(120)),
			Nanos:   rand.Int31n(120),
		},
	},	{
		UserId: "2",
		Name: "Simon",
		PhoneNumber: "01012341234",
		Age: 24,
		Ttt: &timestamppb.Timestamp{
			Seconds: int64(rand.Int31n(120)),
			Nanos:   rand.Int31n(120),
		},
	},
}


