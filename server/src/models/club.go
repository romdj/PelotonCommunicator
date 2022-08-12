package src

type Club struct {
	Id string `json:"id,omitempty"`

	Name string `json:"name"`

	// club status in the store
	Status string `json:"status,omitempty"`

	// club subscription status
	Subscription string `json:"subscription,omitempty"`
}
