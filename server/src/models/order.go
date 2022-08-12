package src

import (
	"time"
)

type Order struct {
	Id int64 `json:"id,omitempty"`

	ClubId int64 `json:"clubId,omitempty"`

	Quantity int32 `json:"quantity,omitempty"`

	ShipDate time.Time `json:"shipDate,omitempty"`

	// Order Status
	Status string `json:"status,omitempty"`

	Complete bool `json:"complete,omitempty"`
}
