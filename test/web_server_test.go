package test

import (
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestWebServerPritunlCheck(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",
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
		nil,
		maxRetries,
		timeBetweenRetries,
		func(status int, _ string) bool {
			return status == expectedStatus
		},
	)
}
