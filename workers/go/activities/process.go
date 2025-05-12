package activities

import "context"

func ProcessGo(ctx context.Context, message string, language string) (string, error) {
	return "Go says: " + message, nil
} 