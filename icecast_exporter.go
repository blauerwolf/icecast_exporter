// Copyright 2016 Markus Lindenberg
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bytes"
	"crypto/tls" // IMPORT AGREGADO
	"encoding/json"
	"flag"
	"io/ioutil"
	"net"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	log "github.com/sirupsen/logrus"
)

const (
	namespace = "icecast"
)

var (
	labelNames = []string{"listenurl", "server_type"}
)

type ISO8601 time.Time

func (ts ISO8601) Time() time.Time {
	return time.Time(ts)
}

func (ts *ISO8601) UnmarshalJSON(data []byte) error {
	parsed, err := time.Parse(`"2006-01-02T15:04:05-0700"`, string(data))
	if err != nil {
		return err
	}
	*ts = ISO8601(parsed)
	return nil
}

type IcecastStatusSource struct {
	Listeners   int     `json:"listeners"`
	Listenurl   string  `json:"listenurl"`
	ServerType  string  `json:"server_type"`
	StreamStart ISO8601 `json:"stream_start_iso8601"`
}

// JSON structure if zero or multiple streams active
type IcecastStatus struct {
	Icestats struct {
		ServerStart ISO8601                 `json:"server_start_iso8601"`
		Source      []IcecastStatusSource   `json:"source,omitifempty"`
	} `json:"icestats"`
}

// JSON structure if exactly one stream active
type IcecastStatusSingle struct {
	Icestats struct {
		ServerStart ISO8601                 `json:"server_start_iso8601"`
		Source      IcecastStatusSource     `json:"source"`
	} `json:"icestats"`
}

// Exporter collects Icecast stats from the given URI and exports them using
// the prometheus metrics package.
type Exporter struct {
	URI   string
	mutex sync.RWMutex

	up                              prometheus.Gauge
	totalScrapes, jsonParseFailures prometheus.Counter
	serverStart                     prometheus.Gauge
	listeners                       *prometheus.GaugeVec
	streamStart                     *prometheus.GaugeVec
	client                          *http.Client
}

// NewExporter returns an initialized Exporter.
func NewExporter(uri string, timeout time.Duration) *Exporter {
	// Crear un transport que ignore la verificación TLS
	transport := &http.Transport{
		Proxy: nil,
		Dial: func(netw, addr string) (net.Conn, error) {
			c, err := net.DialTimeout(netw, addr, timeout)
			if err != nil {
				return nil, err
			}
			if err := c.SetDeadline(time.Now().Add(timeout)); err != nil {
				return nil, err
			}
			return c, nil
		},
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: true, // IGNORAR VERIFICACIÓN TLS
		},
	}

	return &Exporter{
		URI: uri,
		up: prometheus.NewGauge(prometheus.GaugeOpts{
			Namespace: namespace,
			Name:      "up",
			Help:      "Was the last scrape of Icecast successful.",
		}),
		totalScrapes: prometheus.NewCounter(prometheus.CounterOpts{
			Namespace: namespace,
			Name:      "exporter_total_scrapes",
			Help:      "Current total Icecast scrapes.",
		}),
		jsonParseFailures: prometheus.NewCounter(prometheus.CounterOpts{
			Namespace: namespace,
			Name:      "exporter_json_parse_failures",
			Help:      "Number of errors while parsing JSON.",
		}),
		serverStart: prometheus.NewGauge(prometheus.GaugeOpts{
			Namespace: namespace,
			Name:      "server_start",
			Help:      "Timestamp of server startup.",
		}),
		listeners: prometheus.NewGaugeVec(prometheus.GaugeOpts{
			Namespace: namespace,
			Name:      "listeners",
			Help:      "The number of currently connected listeners.",
		}, labelNames),
		streamStart: prometheus.NewGaugeVec(prometheus.GaugeOpts{
			Namespace: namespace,
			Name:      "stream_start",
			Help:      "Timestamp of when the currently active source client connected to this mount point.",
		}, labelNames),
		client: &http.Client{
			Transport: transport,
		},
	}
}

// ... el resto del código se mantiene igual