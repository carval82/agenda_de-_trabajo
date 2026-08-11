<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Company;
use Illuminate\Http\JsonResponse;

class CompanyApiController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json(Company::orderBy('name')->get());
    }
}
