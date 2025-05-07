package test

import (
	"strings"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestWebServerPritunlCheck(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../", // Cambia si tu .tf está en otro directorio
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	publicIP := terraform.Output(t, terraformOptions, "public_ip")
	url := "http://" + publicIP + "/check"

	maxRetries := 30
	timeBetweenRetries := 10 * time.Second
	expectedStatus := 200

	http_helper.HttpGetWithRetryWithCustomValidationE(
		t,
		url,
		nil, // No se necesita configuración TLS para HTTP
		maxRetries,
		timeBetweenRetries,
		func(status int, body string) bool {
			return status == expectedStatus && strings.Contains(body, `"status": "ok"`)
		},
	)
}
