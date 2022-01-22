package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
)

func main() {
	fmt.Println("Starting...")

	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(os.Getenv("AWS_REGION"))},
	)

	if err != nil {
		log.Fatalf("Error starting aws session, %v", err)
	}

	svc := s3.New(sess)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		result, err := svc.ListObjects(&s3.ListObjectsInput{
			Bucket: aws.String(os.Getenv("BUCKET_NAME")),
		})

		if err != nil {
			fmt.Fprint(w, err.Error())
		}

		fmt.Fprint(w, result.GoString())
	})

	log.Fatal(http.ListenAndServe(":80", nil))

	fmt.Println("Started...")
}
