/*
Copyright 2022.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// ODHIntegrationSpec defines the desired state of ODHIntegration
type ODHIntegrationSpec struct {
	// ODHIntegrationSpec defines the desired state of ODHIntegration

	// ISV operator CSV name
	CsvName string `json:"csvName"`

	// Template name for ISV application
	TemplateName string `json:"template,omitempty"`

	// ISV Provider name
	ProviderName string `json:"provider"`

	// Application minimum supported version
	MinSupportedVersion string `json:"minSupportedVersion,omitempty"`

	// // Choose language type to use for processor: oc
	// PreProcessor []CommandType `json:"preprocessor,omitempty"`

}

// ODHIntegrationStatus defines the observed state of ODHIntegration
type ODHIntegrationStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status

// ODHIntegration is the Schema for the odhintegrations API
type ODHIntegration struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   ODHIntegrationSpec   `json:"spec,omitempty"`
	Status ODHIntegrationStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// ODHIntegrationList contains a list of ODHIntegration
type ODHIntegrationList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []ODHIntegration `json:"items"`
}

func init() {
	SchemeBuilder.Register(&ODHIntegration{}, &ODHIntegrationList{})
}
