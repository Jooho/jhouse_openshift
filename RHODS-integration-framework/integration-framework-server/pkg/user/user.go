package user

import (
	"context"

	userpb "github.com/Jooho/integration-framework-grpc-server/pkg/api/v1/user"
	"github.com/Jooho/integration-framework-grpc-server/test/data"
	"google.golang.org/grpc"
)


type userServer struct {
	userpb.UserServer
}

func NewUserServer(s grpc.Server) {
	userpb.RegisterUserServer(&s, &userServer{})
}

// GetUser returns user message by user_id
func (s *userServer) GetUser(ctx context.Context, req *userpb.GetUserRequest) (*userpb.GetUserResponse, error) {
	userID := req.UserId

	var userMessage *userpb.UserMessage
	for _, u := range data.UserData {
		if u.UserId != userID {
			continue
		}
		userMessage = u
		break
	}

	return &userpb.GetUserResponse{
		UserMessage: userMessage,
	}, nil
}


// ListUsers returns all user messages
func (s *userServer) ListUsers(ctx context.Context, req *userpb.ListUsersRequest) (*userpb.ListUsersResponse, error) {
	userMessages := make([]*userpb.UserMessage, len(data.UserData))	
	for i, u := range data.UserData {
		userMessages[i] = u
	}
	return &userpb.ListUsersResponse{
		UserMessages: userMessages,
	}, nil
}