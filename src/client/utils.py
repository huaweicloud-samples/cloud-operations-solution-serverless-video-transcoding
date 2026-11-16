# SPDX-License-Identifier: MIT
# Utility functions for the SaaS client simulator.
# Generates JWT tokens with tenant context for API authentication.

import os
import random
import jwt

# Shared signing key (must match the server-side key in token-manager.js).
# 生产环境通过环境变量 SAAS_JWT_SECRET 注入；下方值为本地演示占位，不得用于生产。
SECRET_KEY = os.environ.get("SAAS_JWT_SECRET", "<your-signing-key>")


class Utils:
    def __init__(self):
        pass

    @staticmethod
    def random_integer(start, end):
        return random.randrange(start, end, 1)

    @staticmethod
    def create_jwt():
        encoded_jwt = jwt.encode(
            {'tenantId': random.choice(['tenant1', 'tenant2', 'tenant3'])},
            SECRET_KEY,
            algorithm='HS256'
        )
        # PyJWT 2.x returns str; 1.x returns bytes
        if isinstance(encoded_jwt, bytes):
            encoded_jwt = encoded_jwt.decode('utf-8')
        return encoded_jwt

    @staticmethod
    def get_headers():
        return {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + Utils.create_jwt()
        }
