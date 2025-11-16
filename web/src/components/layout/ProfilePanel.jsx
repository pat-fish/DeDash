"use client";

import { XMarkIcon } from "@heroicons/react/24/outline";

export default function ProfilePanel({ open, onClose }) {
    return (
        <>
            <div
                onClick={onClose}
                className={`fixed inset-0 z-40 bg-black/40 transition-opacity duration-300
                ${open ? "opacity-100 pointer-events-auto" : "opacity-0 pointer-events-none"}`}
            />

            <aside
                    className={`fixed top-0 right-0 h-full w-full max-w-md bg-white z-50 shadow-xl
                    transform transition-transform duration-300
                    ${open ? "translate-x-0" : "translate-x-full"}`}
                >
                <div className="flex items-center justify-between px-4 py-3 border-b">
                    <h2 className="text-lg font-semibold">Your Account</h2>
                    <button onClick={onClose}>
                        <XMarkIcon className="w-6 h-6 text-gray-600" />
                    </button>
                </div>

                <div className="p-4 space-y-3">
                    <button className="w-full text-left hover:text-purple-600">
                        Profile
                    </button>
                    <button className="w-full text-left hover:text-purple-600">
                        My Orders
                    </button>
                    <button className="w-full text-left hover:text-purple-600">
                        Settings
                    </button>
                    <button className="w-full text-left text-red-500 hover:text-red-600">
                        Log Out
                    </button>
                </div>
            </aside>
        </>
    );
}
